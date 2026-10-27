;;;; parser-stmt-decls-modules.lisp — PHP Parser: include/declare/namespace/use/const/trait/function
;;;; statement parsers

(in-package #:cl-cc/php/statements)

;;; ─── Registered statement parsers (declarations and modules) ─────────────

(defun %php-parse-include-like (rest known-vars name)
  (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
    (values (make-ast-call :func (make-ast-var :name name) :args (list expr))
            (php-skip-semis rest2) kv2)))

(define-php-stmt-parser :include (rest known-vars)
  (%php-parse-include-like rest known-vars 'include))

(define-php-stmt-parser :require (rest known-vars)
  (%php-parse-include-like rest known-vars 'require))

(define-php-stmt-parser :include-once (rest known-vars)
  (%php-parse-include-like rest known-vars 'include-once))

(define-php-stmt-parser :require-once (rest known-vars)
  (%php-parse-include-like rest known-vars 'require-once))

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

(in-package #:cl-cc/php/statements)

(defun %php-parse-declare-alternative-body (stream known-vars)
  "Parse declare(...): stmt* enddeclare; and return its body forms."
  (let ((current (%php-consume-expected :T-COLON stream))
        (stmts nil)
        (kv known-vars))
    (loop
      (setf current (php-skip-semis current))
      (cond
        ((php-at-eof-p current)
         (error "PHP parse error: unterminated declare alternative syntax"))
        ((%php-keyword-p current :enddeclare)
         (return))
        (t
         (multiple-value-bind (stmt rest2 kv2) (php-parse-statement current kv)
           (when stmt (push stmt stmts))
           (setf current rest2
                 kv kv2)))))
    (values (php-finish-let-bindings
             (%php-lower-reference-assignments (nreverse stmts) known-vars))
            (php-skip-semis (cdr current))
            kv)))

(defun %php-declare-body-ast (forms)
  "Return the AST node representing a declare body form list."
  (cond ((rest forms) (make-ast-progn :forms forms))
        ((first forms))
        (t (make-ast-progn :forms nil))))

;;; ─── Declare parsing helpers ───────────────────────────────────────────────

(defun %php-skip-declare-directives (stream)
  "Skip the parenthesized directive list after declare and return the next token."
  (let ((current (%php-consume-expected :T-LPAREN stream))
        (depth 1))
    (loop
      (when (php-at-eof-p current)
        (error "PHP parse error: unterminated declare directive list"))
      (let ((type (php-peek-type current)))
        (cond
          ((eq type :T-LPAREN)
           (incf depth)
           (setf current (cdr current)))
          ((eq type :T-RPAREN)
           (decf depth)
           (setf current (cdr current))
           (when (zerop depth)
             (return)))
          (t
           (setf current (cdr current))))))
    current))

(defun %php-parse-use-imports (stream kind)
  "Parse one PHP use statement body and return import descriptors/rest."
  (let ((current stream)
        (imports nil))
    (loop
      (multiple-value-bind (name rest) (php-parse-qualified-name current)
        (cond
          ((and (eq (php-peek-type rest) :T-BACKSLASH)
                (eq (php-peek-type (cdr rest)) :T-LBRACE))
           (multiple-value-bind (group-imports rest2)
               (%php-parse-group-use-items (cdr rest) name kind)
             (setf imports (append imports group-imports)
                   current rest2)))
          ((eq (php-peek-type rest) :T-LBRACE)
           (multiple-value-bind (group-imports rest2)
               (%php-parse-group-use-items rest name kind)
             (setf imports (append imports group-imports)
                   current rest2)))
          (t
           (multiple-value-bind (alias rest2) (%php-parse-use-alias rest)
             (setf imports (append imports (list (%php-make-import kind name alias))))
             (setf current rest2)))))
      (cond ((eq (php-peek-type current) :T-COMMA)
             (setf current (cdr current)))
            (t (return))))
    (values imports
            (%php-consume-expected :T-SEMI current))))

(defun %php-parse-group-use-items (stream prefix default-kind)
  "Parse `{A, B as C}` group-use items after PREFIX."
  (let ((current (%php-consume-expected :T-LBRACE stream))
        (imports nil))
    (loop
      (multiple-value-bind (kind rest) (%php-optional-use-kind current)
        (multiple-value-bind (name rest2) (php-parse-qualified-name rest)
          (multiple-value-bind (alias rest3) (%php-parse-use-alias rest2)
            (push (%php-make-import (or kind default-kind)
                                    (%php-join-qualified-prefix prefix name)
                                    alias)
                  imports)
            (setf current rest3))))
      (cond ((eq (php-peek-type current) :T-COMMA)
             (setf current (cdr current))
             (when (eq (php-peek-type current) :T-RBRACE) (return)))
            (t (return))))
    (values (nreverse imports) (%php-consume-expected :T-RBRACE current))))

(defun %php-join-qualified-prefix (prefix name)
  "Join import PREFIX and NAME with a PHP namespace separator."
  (cond ((or (null prefix) (string= prefix "")) name)
        ((or (null name) (string= name "")) prefix)
        ((char= (char prefix (1- (length prefix))) #\\) (concatenate 'string prefix name))
        (t (format nil "~A\\~A" prefix name))))

(defun %php-make-import (kind name alias)
  "Build a PHP import descriptor plist."
  (list :type kind :name name :alias alias))

(defun %php-parse-use-alias (stream)
  "Parse optional `as Alias` and return alias/rest."
  (if (%php-keyword-p stream :as)
      (multiple-value-bind (alias-name rest) (php-parse-qualified-name (cdr stream))
        (values alias-name rest))
      (values nil stream)))

(defun %php-optional-use-kind (stream)
  "Return optional group-use kind qualifier and stream after it."
  (cond ((%php-keyword-p stream :function) (values :function (cdr stream)))
        ((%php-keyword-p stream :const) (values :const (cdr stream)))
        (t (values nil stream))))

;;; ─── Use/import parsing helpers ──────────────────────────────────────────

(defun %php-use-kind (stream)
  "Return use kind and stream after optional function/const qualifier."
  (cond ((%php-keyword-p stream :function) (values :function (cdr stream)))
        ((%php-keyword-p stream :const) (values :const (cdr stream)))
        (t (values :class stream))))
