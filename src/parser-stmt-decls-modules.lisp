;;;; packages/php/src/parser-stmt-decls-modules.lisp — PHP Parser: include/declare/namespace/use/const/trait/function statement parsers

(in-package :cl-cc/php)

;;; ─── Registered statement parsers (declarations and modules) ─────────────

(defun %php-parse-include-like (rest known-vars name)
  (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
    (values (make-ast-call :func (make-ast-var :name name) :args (list expr))
            (php-skip-semis rest2) kv2)))

(define-php-stmt-parser :include (rest known-vars) (%php-parse-include-like rest known-vars 'include))

(define-php-stmt-parser :require (rest known-vars) (%php-parse-include-like rest known-vars 'require))

(define-php-stmt-parser :include-once (rest known-vars) (%php-parse-include-like rest known-vars 'include-once))

(define-php-stmt-parser :require-once (rest known-vars) (%php-parse-include-like rest known-vars 'require-once))

(define-php-stmt-parser :declare (rest known-vars)
  (let ((after-directives (%php-skip-declare-directives rest)))
    (cond
      ((eq (php-peek-type after-directives) :T-SEMI)
       (values (make-ast-progn :forms nil)
               (php-skip-semis after-directives)
               known-vars))
      ((eq (php-peek-type after-directives) :T-COLON)
       (multiple-value-bind (body rest2 kv2)
           (%php-parse-declare-alternative-body after-directives known-vars)
         (values (%php-declare-body-ast body)
                 (php-skip-semis rest2)
                 kv2)))
      (t
       (multiple-value-bind (body rest2 kv2)
           (%php-parse-statement-body after-directives known-vars)
         (values (%php-declare-body-ast body)
                 (php-skip-semis rest2)
                 kv2))))))

(define-php-stmt-parser :goto (rest known-vars)
  (multiple-value-bind (label-tok rest2) (php-expect :T-IDENT rest)
    (values (make-ast-go :tag (php-ident-sym (php-tok-value label-tok)))
            (php-skip-semis rest2) known-vars)))

(define-php-stmt-parser :namespace (rest known-vars)
  (multiple-value-bind (namespace-name after-name)
      (if (eq (php-peek-type rest) :T-LBRACE)
          (values nil rest)
          (php-parse-qualified-name rest))
    (cond
      ((eq (php-peek-type after-name) :T-LBRACE)
       (multiple-value-bind (forms rest2 kv2)
           (%php-parse-namespace-block-body after-name known-vars namespace-name)
         (setf *php-pending-top-level-forms* forms)
         (values nil rest2 kv2)))
      ((eq (php-peek-type after-name) :T-SEMI)
       (setf *php-current-namespace* namespace-name
             *php-current-imports* nil)
       (values nil (php-skip-semis after-name) known-vars))
      (t (error "PHP parse error: expected { or ; after namespace declaration, got ~S"
                (php-peek after-name))))))

(define-php-stmt-parser :use (rest known-vars)
  (multiple-value-bind (kind use-rest) (%php-use-kind rest)
    (multiple-value-bind (imports rest2) (%php-parse-use-imports use-rest kind)
      (setf *php-current-imports* (append *php-current-imports* imports))
      (values nil rest2 known-vars))))

(defun %php-parse-top-level-const (stream known-vars)
  "Parse PHP top-level const declarations."
  (let ((current stream)
        (forms nil))
    (loop
      (multiple-value-bind (qualified-name after-name)
          (php-parse-qualified-name current)
        (unless qualified-name
          (error "PHP parse error: expected constant name after const"))
        (unless (and (eq (php-peek-type after-name) :T-OP)
                     (equal (php-peek-value after-name) "="))
          (error "PHP parse error: expected = after const name ~A" qualified-name))
        (multiple-value-bind (value after-value kv2)
            (php-parse-expr (cdr after-name) known-vars)
          (setf known-vars kv2
                current after-value)
          (push (make-ast-defvar
                 :name (php-ident-sym
                        (php-resolve-qualified-name qualified-name :const))
                 :value value
                 :kind 'defparameter
                 :imports (list :php-constant t))
                forms)))
      (if (eq (php-peek-type current) :T-COMMA)
          (setf current (cdr current))
          (return)))
    (setf current (%php-consume-expected :T-SEMI current))
    (values (if (rest forms)
                (make-ast-progn :forms (nreverse forms))
                (first forms))
            (php-skip-semis current)
            known-vars)))

(define-php-stmt-parser :const (rest known-vars)
  (%php-parse-top-level-const rest known-vars))

(define-php-stmt-parser :trait (rest known-vars) (%php-parse-classlike rest known-vars :kind :trait))

(define-php-stmt-parser :interface (rest known-vars) (%php-parse-classlike rest known-vars :kind :interface))

(define-php-stmt-parser :enum (rest known-vars) (%php-parse-classlike rest known-vars :enum-p t))

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
                                                            param-types return-type param-attributes nil
                                                            :function returns-by-ref)
                                             :body wrapped-body)
                            rest known-vars))))))))))))
