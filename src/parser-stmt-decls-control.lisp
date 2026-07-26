;;;; parser-stmt-decls-control.lisp — PHP Parser: registered control-flow statement parsers

(in-package :cl-cc/php)

;;; ─── Registered statement parsers (control flow) ─────────────────────────

(define-php-stmt-parser :echo (rest known-vars)
  ;; Echo supports comma-separated expressions: echo 1, 2, 3;
  ;; Each value is converted with PHP's string semantics (true -> "1", false/null
  ;; -> "", arrays -> "Array", numbers/strings as-is) via %php-concat, which calls
  ;; %php-stringify per argument. Without this echo went straight to ast-print's
  ;; generic VM printer, so a boolean (e.g. the result of == / a comparison)
  ;; printed as "T"/"NIL" instead of PHP's "1"/"".
  (let ((exprs nil) (current rest) (kv known-vars))
    (loop
      (multiple-value-bind (expr rest2 kv2) (php-parse-expr current kv)
        (push expr exprs)
        (setf current rest2 kv kv2))
      (unless (and current (eq (php-peek-type current) :T-COMMA))
        (return))
      (setf current (cdr current)))
    ;; echo emits its arguments verbatim with NO trailing newline. Route through
    ;; the PHP output helper so ob_start/ob_get_* can capture emitted text.
    (values (%php-call 'cl-cc/php::%php-output-write
                       (apply #'%php-call 'cl-cc/php::%php-concat (nreverse exprs)))
            (php-skip-semis current) kv)))

(define-php-stmt-parser :return (rest known-vars)
  (if (eq (php-peek-type rest) :T-SEMI)
      (values (make-ast-return-from :name nil :value (make-ast-quote :value nil))
              (php-skip-semis rest) known-vars)
      (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
        (values (make-ast-return-from :name nil :value expr) (php-skip-semis rest2) kv2))))

(define-php-stmt-parser :if (rest known-vars)
  (multiple-value-bind (cond-expr rest2 kv2) (%php-parse-paren-expr rest known-vars)
    (multiple-value-bind (then-stmts rest3 kv3 else-ast) (%php-parse-if-tail rest2 kv2)
      (values (make-ast-if :cond (%php-truthy-call cond-expr)
                           :then (make-ast-progn :forms then-stmts)
                           :else else-ast)
              rest3 kv3))))

(define-php-stmt-parser :while (rest known-vars)
  (multiple-value-bind (cond-expr rest2 kv2) (%php-parse-paren-expr rest known-vars)
    (let* ((*php-loop-continue-target* (gensym "WHILE-LOOP-"))
           (*php-loop-break-target* (gensym "WHILE-END-"))
           (*php-break-targets* (cons *php-loop-break-target* *php-break-targets*))
           (*php-continue-targets* (cons *php-loop-continue-target* *php-continue-targets*)))
      (multiple-value-bind (body-stmts rest3 kv3) (%php-parse-statement-body rest2 kv2)
        (values (%php-lower-while-with-label
                 cond-expr
                  body-stmts
                 *php-loop-continue-target*)
                rest3 kv3)))))

(define-php-stmt-parser :for (rest known-vars)
  (let ((rest (%php-consume-expected :T-LPAREN rest)))
    (multiple-value-bind (init rest kv)
        (if (eq (php-peek-type rest) :T-SEMI)
            (values (make-ast-quote :value nil) rest known-vars)
            (php-parse-expr rest known-vars))
      (let ((rest (%php-consume-expected :T-SEMI rest)))
        (multiple-value-bind (cond-expr rest kv)
            (if (eq (php-peek-type rest) :T-SEMI)
                (values (make-ast-quote :value t) rest kv)
                (php-parse-expr rest kv))
          (let ((rest (%php-consume-expected :T-SEMI rest)))
            (multiple-value-bind (incr rest kv)
                (if (eq (php-peek-type rest) :T-RPAREN)
                    (values (make-ast-quote :value nil) rest kv)
                    (php-parse-expr rest kv))
              (let* ((rest (%php-consume-expected :T-RPAREN rest))
                      (*php-loop-continue-target* (gensym "FOR-LOOP-"))
                      (*php-loop-break-target* (gensym "FOR-END-"))
                      (*php-break-targets* (cons *php-loop-break-target* *php-break-targets*))
                      (*php-continue-targets* (cons *php-loop-continue-target* *php-continue-targets*)))
                (multiple-value-bind (body-stmts rest _) (%php-parse-statement-body rest kv)
                  (declare (ignore _))
                  ;; The init (e.g. $i = 1) lowers to an empty-bodied ast-let when
                  ;; it introduces a new variable; nest the loop inside that let
                  ;; (via php-finish-let-bindings) so the loop var is visible to
                  ;; the condition, body and increment. Otherwise it stays a progn.
                  (values (make-ast-progn
                           :forms (php-finish-let-bindings
                                   (list init (%php-lower-for-with-labels
                                               cond-expr
                                               body-stmts
                                               incr
                                               *php-loop-continue-target*))))
                          rest kv))))))))))

(defun %php-lower-foreach-by-ref (arr-expr var-sym body-stmts loop-tag &optional key-sym)
  "Lower 'foreach ($arr as &$val)' -- BODY-FN receives a ref box; writes back."
  (declare (ignore loop-tag))
  (let ((box-sym (gensym "FOREACH-BOX-"))
        (key-param (gensym "FOREACH-KEY-")))
    (%php-call 'cl-cc/php::%php-foreach-by-ref
               arr-expr
               (make-ast-lambda
                :params (list box-sym key-param)
                :body (list
                       (make-ast-let
                        :bindings (append
                                   (when key-sym
                                     (list (cons key-sym (make-ast-var :name key-param))))
                                   (list (cons var-sym (make-ast-var :name box-sym))))
                        :body (%php-rewrite-ref-vars body-stmts (list var-sym))))))))

(define-php-stmt-parser :foreach (rest known-vars)
  (let ((rest2 (%php-consume-expected :T-LPAREN rest)))
    (multiple-value-bind (arr-expr rest3 kv3) (php-parse-expr rest2 known-vars)
      (let ((rest4 (if (%php-keyword-p rest3 :as) (cdr rest3) (error "foreach: expected 'as'"))))
        ;; Detect by-reference on the value position: foreach ($arr as &$val)
        (let* ((by-ref-p (%php-reference-token-p rest4))
               (rest4b (if by-ref-p (cdr rest4) rest4)))
          (multiple-value-bind (var-tok rest5) (php-expect :T-VAR rest4b)
            (let ((key-sym nil)
                  (var-sym (php-var-sym (php-tok-value var-tok)))
                  (val-by-ref-p by-ref-p)
                  (rest6 rest5))
              ;; foreach ($arr as $key => &$val) or ($arr as $key => $val)
              (when (and rest6 (eq (php-peek-type rest6) :T-OP) (equal "=>" (php-peek-value rest6)))
                (let* ((after-arrow (cdr rest6))
                       (val-ref-p (%php-reference-token-p after-arrow))
                       (after-ref (if val-ref-p (cdr after-arrow) after-arrow)))
                  (multiple-value-bind (val-tok rest7) (php-expect :T-VAR after-ref)
                    (setf key-sym var-sym
                          var-sym (php-var-sym (php-tok-value val-tok))
                          val-by-ref-p val-ref-p
                          rest6 rest7))))
              (let* ((*php-loop-continue-target* (gensym "FOREACH-LOOP-"))
                     (*php-loop-break-target* (gensym "FOREACH-END-"))
                     (*php-break-targets* (cons *php-loop-break-target* *php-break-targets*))
                     (*php-continue-targets* (cons *php-loop-continue-target* *php-continue-targets*)))
                (multiple-value-bind (body-stmts rest8 kv8)
                    (%php-parse-statement-body (%php-consume-expected :T-RPAREN rest6) kv3)
                  (values (if val-by-ref-p
                              (%php-lower-foreach-by-ref
                               arr-expr var-sym body-stmts
                               *php-loop-continue-target* key-sym)
                              (%php-lower-foreach-with-label
                               arr-expr var-sym body-stmts
                               *php-loop-continue-target* key-sym))
                          rest8 kv8))))))))))

(define-php-stmt-parser :unset (rest known-vars)
  (let ((current (%php-consume-expected :T-LPAREN rest))
        (forms nil)
        (kv known-vars))
    (unless (eq (php-peek-type current) :T-RPAREN)
      (loop
        (multiple-value-bind (target rest2 kv2) (php-parse-expr current kv)
          (cond
            ((%php-array-ref-call-p target)
             (destructuring-bind (array key) (ast-call-args target)
               (push (%php-array-unset-call array key) forms)))
            ((ast-var-p target)
             (push (make-ast-setq :var (ast-var-name target)
                                  :value (make-ast-quote :value +php-null+))
                   forms)
             (setf kv (remove (ast-var-name target) kv2 :test #'eq)))
            ((ast-slot-value-p target)
             (push (make-ast-set-slot-value
                    :object (ast-slot-value-object target)
                    :slot (ast-slot-value-slot target)
                    :value (make-ast-quote :value +php-null+))
                   forms))
            (t
             (error "PHP parse error: unsupported unset target ~S" target)))
          (setf current rest2)
          (cond
            ((eq (php-peek-type current) :T-COMMA)
             (setf current (cdr current)))
            ((eq (php-peek-type current) :T-RPAREN)
             (return))
            (t
             (error "PHP parse error: expected comma or ) in unset, got ~S"
                    (php-peek current)))))))
    (setf current (%php-consume-expected :T-RPAREN current))
    (values (if (rest forms)
                (make-ast-progn :forms (nreverse forms))
                (or (first forms) (make-ast-quote :value +php-null+)))
            (php-skip-semis current)
            kv)))

(define-php-stmt-parser :do (rest known-vars)
  (let* ((*php-loop-continue-target* (gensym "DO-WHILE-LOOP-"))
         (*php-loop-break-target* (gensym "DO-WHILE-END-"))
         (*php-break-targets* (cons *php-loop-break-target* *php-break-targets*))
         (*php-continue-targets* (cons *php-loop-continue-target* *php-continue-targets*)))
    (multiple-value-bind (body-stmts rest2 kv2) (%php-parse-statement-body rest known-vars)
      (unless (%php-keyword-p rest2 :while)
        (error "PHP parse error: expected while after do body"))
      (multiple-value-bind (cond-expr rest3 kv3) (%php-parse-paren-expr (cdr rest2) kv2)
        (values (%php-lower-do-while-with-label
                 cond-expr
                  body-stmts
                 *php-loop-continue-target*)
                (php-skip-semis rest3) kv3)))))

(define-php-stmt-parser :switch (rest known-vars)
  (multiple-value-bind (switch-expr rest2 kv2) (%php-parse-paren-expr rest known-vars)
    (let* ((break-tag (gensym "SWITCH-END-"))
           (*php-loop-break-target* break-tag)
           (*php-break-targets* (cons break-tag *php-break-targets*)))
      (multiple-value-bind (cases default-body rest3 kv3 warnings) (%php-parse-switch-body rest2 kv2 break-tag)
        (values (php-lower-switch switch-expr cases default-body break-tag warnings) rest3 kv3)))))

(define-php-stmt-parser :try (rest known-vars)
  (multiple-value-bind (try-body rest2 kv2) (php-parse-block rest known-vars)
    (let ((clauses nil) (finally-body nil) (current rest2) (kv kv2))
      (loop while (%php-keyword-p current :catch)
            do (setf current (%php-consume-expected :T-LPAREN (cdr current)))
               (multiple-value-bind (type-sym after-types)
                   (%php-parse-catch-type-list current)
                 (setf current after-types)
                 (let ((var-sym nil))
                   (when (eq (php-peek-type current) :T-VAR)
                     (setf var-sym (php-var-sym (php-peek-value current))
                           current (cdr current)))
                   (setf current (%php-consume-expected :T-RPAREN current))
                   (multiple-value-bind (catch-body rest3 kv3) (php-parse-block current kv)
                     (push (list* type-sym var-sym catch-body) clauses)
                     (setf current rest3 kv kv3)))))
      (when (%php-keyword-p current :finally)
        (multiple-value-bind (body rest3 kv3) (php-parse-block (cdr current) kv)
          (setf finally-body body current rest3 kv kv3)))
      (let ((protected (%php-lower-try-catches try-body (nreverse clauses))))
        (values (make-ast-unwind-protect :protected protected :cleanup finally-body)
                current kv)))))

(define-php-stmt-parser :continue (rest known-vars)
  (multiple-value-bind (level rest2) (%php-parse-control-level rest)
    (let* ((target (%php-continue-target level))
           (current (if (eq (php-peek-type rest2) :T-SEMI) rest2 (%php-skip-to-stmt-end rest2))))
      (unless target
        (error "PHP parse error: continue~@[ ~D~] has no matching loop" level))
      (values (make-ast-go :tag target)
              (php-skip-semis current) known-vars))))

(define-php-stmt-parser :break (rest known-vars)
  (multiple-value-bind (level rest2) (%php-parse-control-level rest)
    (let* ((target (%php-break-target level))
           (current (if (eq (php-peek-type rest2) :T-SEMI) rest2 (%php-skip-to-stmt-end rest2))))
      (unless target
        (error "PHP parse error: break~@[ ~D~] has no matching loop or switch" level))
      (values (make-ast-go :tag target)
              (php-skip-semis current) known-vars))))

(define-php-stmt-parser :throw (rest known-vars)
  (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
    (values (make-ast-throw :tag (make-ast-quote :value 'php-exception)
                            :value (%php-exception-payload-call expr))
            (php-skip-semis rest2) kv2)))
