;;;; parser-call-args.lisp — PHP argument-list syntax beyond plain positional
;;;; arguments.
;;;;
;;;; Named arguments (PHP 8.0, `f(name: $v)`) and first-class callables
;;;; (PHP 8.1, `strlen(...)`) are one concern: both are decided by looking at
;;;; the token immediately after the opening paren of a call, and both end up
;;;; rewriting the argument list the ordinary call parser would have built.
;;;;
;;;; Called from parser-expr-operator.lisp, which is compiled before this file;
;;;; that forward reference predates the split.

(in-package #:cl-cc/php/functions)

(defun %php-arg-descriptor-expression (descriptor)
  "Return the AST expression carried by a parsed PHP call argument DESCRIPTOR."
  (ecase (first descriptor)
    (:positional (second descriptor))
    (:named (third descriptor))
    (:spread (second descriptor))))

(defun %php-named-args-to-positional (arg-descriptors)
  "Lower named args to positional ast expressions for the call AST.
Named args appear as :positional after reordering since the call AST only
holds a flat list. Unknown name order is preserved in declaration order."
  (mapcar #'%php-arg-descriptor-expression arg-descriptors))

;;; ─── First-Class Callables (PHP 8.1) ────────────────────────────────────────
;;;
;;; PHP 8.1 allows creating callable references with `...`:
;;;
;;;   $fn = strlen(...);
;;;   $closure = $obj->method(...);
;;;
;;; We detect T-ELLIPSIS as the sole argument in a call arglist and lower to
;;; a runtime callable reference.

(defun %php-first-class-callable-p (stream)
  "Return true when STREAM holds `( ... )` — first-class callable syntax."
  (and stream
       (eq (php-peek-type stream) :T-LPAREN)
       (cdr stream)
       (eq (php-peek-type (cdr stream)) :T-ELLIPSIS)
       (cddr stream)
       (eq (php-peek-type (cddr stream)) :T-RPAREN)))

(defun %php-callable-ref (func-name-ast)
  "Create a callable reference AST. Returns a lambda that calls FUNC-NAME-AST."
  ;; Lower strlen(...) to a callable trampoline that applies the PHP function.
  (let ((args-sym (gensym "CALLABLE-ARGS-")))
    (make-ast-lambda
     :params (list args-sym)
     :body (list (make-ast-call
                  :func (make-ast-var :name 'apply)
                  :args (list func-name-ast (make-ast-var :name args-sym)))))))

(defun php-cst-parse-param-list (ts)
  "Parse (type? $param, ...) for function/method definitions. Returns list of CST tokens."
  (php-ts-expect ts :T-LPAREN nil "parameter list")
  (if (php-ts-at-type-p ts :T-RPAREN)
      (progn (php-ts-advance ts) nil)
      (let ((params nil))
        (loop
          ;; Skip optional type annotation
          (when (member (php-ts-peek-type ts) '(:T-TYPE :T-IDENT :T-NULLABLE))
            (php-ts-advance ts)
            (when (member (php-ts-peek-type ts) '(:T-TYPE :T-IDENT))
              (php-ts-advance ts)))
          ;; Expect $var
          (let ((var-tok (php-ts-expect ts :T-VAR nil "parameter")))
            (when var-tok (push (%php-tok-to-cst var-tok) params)))
          ;; Skip optional default value
          (when (and (php-ts-at-type-p ts :T-OP)
                     (equal "=" (php-ts-peek-value ts)))
            (php-ts-advance ts)
            (php-cst-parse-expr ts)) ; parse and discard default
          (if (php-ts-at-type-p ts :T-COMMA)
              (php-ts-advance ts)
              (return)))
        (php-ts-expect ts :T-RPAREN nil "parameter list")
        (nreverse params))))

(defun %parse-php-function-def-stmt (ts)
  (let* ((kw-tok   (php-ts-advance ts))
         (name-tok (php-ts-expect ts :T-IDENT nil "function name"))
         (params   (php-cst-parse-param-list ts)))
    (when (php-ts-at-type-p ts :T-COLON)
      (php-ts-advance ts)
      (when (member (php-ts-peek-type ts) '(:T-TYPE :T-IDENT :T-NULLABLE))
        (php-ts-advance ts)
        (when (member (php-ts-peek-type ts) '(:T-TYPE :T-IDENT))
          (php-ts-advance ts))))
    (let ((body-stmts (php-cst-parse-block ts)))
      (%php-cst-interior :function-def
                         (append (list (%php-tok-to-cst kw-tok))
                                 (when name-tok (list (%php-tok-to-cst name-tok)))
                                 (list (%php-cst-interior :params params))
                                 (list (%php-cst-interior :body body-stmts)))))))

(eval-when (:load-toplevel :execute) (register-php-cst-keyword-statement-parser :function #'%parse-php-function-def-stmt))

(in-package #:cl-cc/php/functions)

(define-php-stmt-parser :function (rest known-vars)
  (let* ((returns-by-ref (%php-reference-token-p rest))
         (rest (if returns-by-ref (cdr rest) rest)))
  (multiple-value-bind (name-tok rest) (php-expect :T-IDENT rest)
    (let ((fn-name (php-ident-sym
                    (php-resolve-qualified-name (php-tok-value name-tok) :function))))
      (multiple-value-bind (params rest param-types param-attributes by-ref-indices
                            param-defaults variadic-param)
          (php-parse-param-list rest)
        (multiple-value-bind (return-type rest) (php-parse-return-type rest)
          ;; Register by-reference parameter info for call-site lowering
          (when by-ref-indices
            (setf (gethash (symbol-name fn-name) *php-by-ref-param-registry*)
                  by-ref-indices))
          (%php-register-named-callable-params fn-name params param-defaults variadic-param)
          ;; Parameters with `= default` become &optional params so a call that
          ;; omits them binds the default instead of leaving them unset.
          (multiple-value-bind (required optionals)
              (%php-split-params-by-defaults params param-defaults)
            ;; Abstract / interface method signature: `function f(...): T;` with no
            ;; body. Produce a body-less ast-defun (a signature) instead of
            ;; requiring a brace block.
            (if (eq (php-peek-type rest) :T-SEMI)
                (values (make-ast-defun :name fn-name
                                         :params required
                                         :optional-params optionals
                                         :declarations (%php-function-declarations
                                                        param-types return-type param-attributes nil
                                                        :function returns-by-ref)
                                         :body nil)
                        (php-skip-semis rest) known-vars)
                (multiple-value-bind (body-stmts rest _)
                    (php-parse-block rest (append params
                                                  (when variadic-param (list variadic-param))
                                                  known-vars))
                  (declare (ignore _))
                  (let* ((by-ref-params (remove nil
                                                (mapcar (lambda (idx) (nth idx params))
                                                        by-ref-indices)))
                         (callable-body (%php-callable-body body-stmts))
                         (callable-body (if by-ref-params
                                            (%php-rewrite-ref-vars callable-body by-ref-params)
                                            callable-body)))
                    (multiple-value-bind (rest-param wrapped-body)
                        (%php-variadic-rest-binding variadic-param callable-body)
                    (values (make-ast-defun :name fn-name
                                             :params required
                                             :optional-params optionals
                                             :rest-param rest-param
                                             :declarations (%php-function-declarations
                                                            param-types return-type param-attributes
                                                            nil
                                                            :function returns-by-ref)
                                             :body wrapped-body)
                            rest known-vars))))))))))))
