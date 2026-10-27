;;;; frontend/php/parser-expr-advanced-match.lisp -- PHP Match Expression Lowering
;;;;
;;;; Split from parser-expr-advanced.lisp.

(in-package #:cl-cc/php/match)

;;; ─── Match Expression Lowering ───────────────────────────────────────────────

(defun %php-match-error-call ()
  "Return the fallback call used when no PHP match arm applies."
  (%php-call '%php-match-error))

(defun %php-build-match-condition (subject-sym tests)
  "Build the condition for one match arm: true when SUBJECT === any of TESTS.
Lowered as a short-circuit nested if rather than (ast-binop :op 'or ...) — codegen
has no emitter for an :or binop, so a multi-condition arm (1, 2 => …) silently
failed to compile and the whole match produced nothing."
  (labels ((eq-test (test)
             (%php-call '%php-eq-strict
                        (make-ast-var :name subject-sym) test))
           (build (ts)
             ;; Single (or final) test: the bare strict-equality call, which is
             ;; already a boolean. Earlier tests chain via if so the arm matches
             ;; when SUBJECT === any test, without an :or binop.
             (if (cdr ts)
                 (make-ast-if :cond (eq-test (car ts))
                              :then (make-ast-quote :value t)
                              :else (build (cdr ts)))
                 (eq-test (car ts)))))
    (build tests)))

(defun %php-lower-match (subject arms default-expr)
  "Lower PHP match SUBJECT and ARMS to a subject let plus nested ast-if chain."
  (let ((subject-sym (gensym "PHP-MATCH-SUBJECT-")))
    (labels ((chain (remaining)
               (if remaining
                   (destructuring-bind (tests . value) (car remaining)
                     (make-ast-if
                      :cond (%php-build-match-condition subject-sym tests)
                      :then value
                      :else (chain (cdr remaining))))
                   (or default-expr (%php-match-error-call)))))
      (make-ast-let
       :bindings (list (cons subject-sym subject))
       :body (list (chain arms))))))

(defun %php-parse-match-arm-tests (stream known-vars)
  "Parse one PHP match arm condition list or default marker."
  (if (and (eq (php-peek-type stream) :T-KEYWORD)
           (eq (php-peek-value stream) :default))
      (values :default (cdr stream) known-vars)
      (let ((tests nil)
            (current stream)
            (kv known-vars))
        (loop
          (multiple-value-bind (test rest kv2) (php-parse-expr current kv)
            (push test tests)
            (setf current rest kv kv2))
          (cond
            ((%php-double-arrow-p current) (return))
            ((eq (php-peek-type current) :T-COMMA)
             (setf current (cdr current)))
            (t (error "PHP parse error: expected comma or => in match arm, got ~S"
                      (php-peek current)))))
        (values (nreverse tests) current kv))))

(defun %php-parse-match-expression (stream known-vars)
  "Parse match(expr) { arms } and lower to let plus nested ifs."
  (let ((current (%php-consume-expected :T-LPAREN stream)))
    (multiple-value-bind (subject rest kv) (php-parse-expr current known-vars)
      (setf current (%php-consume-expected :T-RPAREN rest))
      (setf current (%php-consume-expected :T-LBRACE current))
      (let ((arms nil)
            (default-expr nil)
            (kv-current kv))
        (loop
          (when (eq (php-peek-type current) :T-RBRACE)
            (return))
          (multiple-value-bind (tests rest2 kv2) (%php-parse-match-arm-tests current kv-current)
            (setf current rest2 kv-current kv2)
            (unless (%php-double-arrow-p current)
              (error "PHP parse error: expected => in match arm, got ~S" (php-peek current)))
            (multiple-value-bind (arrow-token rest3) (php-consume current)
              (declare (ignore arrow-token))
              (multiple-value-bind (value rest4 kv4) (php-parse-expr rest3 kv-current)
                (if (eq tests :default)
                    (setf default-expr value)
                    (push (cons tests value) arms))
                (setf current rest4 kv-current kv4))))
          (cond
            ((eq (php-peek-type current) :T-COMMA)
             (setf current (cdr current)))
            ((eq (php-peek-type current) :T-RBRACE))
            (t (error "PHP parse error: expected comma or } after match arm, got ~S"
                      (php-peek current)))))
        (values (%php-lower-match subject (nreverse arms) default-expr)
                (%php-consume-expected :T-RBRACE current)
                kv-current)))))

;;; ─── Exhaustiveness failure ─────────────────────────────────────────────────

(defun %php-match-error ()
  "Signal an UnhandledMatchError equivalent for a non-exhaustive PHP match."
  (%php-fatal-error "PHP UnhandledMatchError: Unhandled match case"))
;;; ─── Exhaustiveness failure ─────────────────────────────────────────────────

(progn
  (defun %php-cst-parse-match-expression (ts)
    "Parse match(expr) { arms } into a conservative CST node."
    (let* ((kw-tok (%php-tok-to-cst (php-ts-advance ts)))
           (lp (%php-tok-to-cst (php-ts-expect ts :T-LPAREN "match(")))
           (subject (php-cst-parse-expr ts))
           (rp (%php-tok-to-cst (php-ts-expect ts :T-RPAREN "match(expr)")))
           (lb (%php-tok-to-cst (php-ts-expect ts :T-LBRACE "match{")))
           (arms (loop while (not (php-ts-at-type-p ts :T-RBRACE))
                       for arm = (php-cst-parse-expr ts)
                       when arm collect arm
                       when (php-ts-at-type-p ts :T-COMMA)
                       do (php-ts-advance ts)))
           (rb (%php-tok-to-cst (php-ts-expect ts :T-RBRACE "match}"))))
      (%php-cst-interior :match
                         (list* kw-tok lp subject rp lb (append arms (list rb))))))
  (eval-when (:load-toplevel :execute)
    (register-php-cst-keyword-expression-parser
     :match #'%php-cst-parse-match-expression))
  (defun %php-parse-match-keyword-expression (stream known-vars)
    "Parse a PHP match keyword expression."
    (multiple-value-bind (token rest) (php-consume stream)
      (declare (ignore token))
      (%php-parse-match-expression rest known-vars)))
  (eval-when (:load-toplevel :execute)
    (register-php-expression-keyword-parser
     :match #'%php-parse-match-keyword-expression)))
