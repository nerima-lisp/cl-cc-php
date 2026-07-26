;;;; parser-stmt-decls.lisp — PHP Parser: catch/enum/class-like, use-import, and declare parsing
;;;; helpers

(in-package :cl-cc/php)

;;; ─── Catch type parsing ──────────────────────────────────────────────────

(defun %php-catch-type-token-p (token)
  "Return true when TOKEN can appear as a PHP catch class name."
  (and token
       (member (php-tok-type token) '(:T-IDENT :T-TYPE :T-KEYWORD) :test #'eq)))

(defun %php-parse-catch-type-list (stream)
  "Parse a PHP catch type or union type list, returning (values type stream)."
  (let ((types nil)
        (current stream))
    (unless (or (eq (php-peek-type current) :T-BACKSLASH)
                (%php-catch-type-token-p (php-peek current)))
      (error "PHP parse error: expected catch type, got ~S" (php-peek current)))
    (loop
      (multiple-value-bind (catch-name after-name) (php-parse-qualified-name current)
        (push (php-ident-sym (php-resolve-qualified-name catch-name :class)) types)
        (setf current after-name))
      (if (and (eq (php-peek-type current) :T-OP)
               (equal (php-peek-value current) "|"))
          (progn
            (setf current (cdr current))
            (unless (or (eq (php-peek-type current) :T-BACKSLASH)
                        (%php-catch-type-token-p (php-peek current)))
              (error "PHP parse error: expected catch type after |, got ~S" (php-peek current))))
          (return)))
    (let ((ordered (nreverse types)))
      (values (if (rest ordered) ordered (first ordered)) current))))

;;; ─── Enum support helpers ────────────────────────────────────────────────

(defun %php-enum-backing-type (type)
  "Return normalized PHP enum backing TYPE metadata."
  (cond ((null type) nil)
        ((string= type "int") :int)
        ((string= type "string") :string)
        (t (error "PHP parse error: enum backing type must be int or string, got ~S" type))))

(defun %php-parse-enum-backing-type (stream)
  "Parse optional : int|string enum backing type."
  (if (eq (php-peek-type stream) :T-COLON)
      (multiple-value-bind (type rest) (php-parse-type-annotation (cdr stream))
        (values (%php-enum-backing-type type) rest))
      (values nil stream)))

(defun %php-enum-case-initform (class-name case-name value)
  "Build an AST initform creating one PHP enum case singleton."
  (%php-call 'cl-cc/php::%php-enum-make-case
             (make-ast-quote :value class-name)
             (make-ast-quote :value case-name)
             (or value (make-ast-quote :value +php-null+))))

(defun %php-parse-enum-case (stream known-vars class-name enum-type &optional attributes)
  "Parse case NAME [= VALUE]; in an enum body."
  (declare (ignore enum-type))
  (let ((current (cdr stream)))
    (multiple-value-bind (name-tok rest) (php-expect :T-IDENT current)
      (let* ((case-name (php-ident-sym (php-tok-value name-tok)))
             (value nil)
             (current rest))
        (when (%php-assignment-op-p current)
          (multiple-value-bind (expr rest2 kv2) (php-parse-expr (cdr current) known-vars)
            (declare (ignore kv2))
            (setf value expr
                  current rest2)))
        (values (make-ast-slot-def :name case-name
                                   :type enum-type
                                   :initform (%php-enum-case-initform class-name case-name value)
                                   :allocation :class
                                   :imports (append (list :php-enum-case t
                                                          :php-enum-value value)
                                                    (%php-attribute-metadata attributes :constant)))
                (php-skip-semis current)
                (list :name case-name :value value))))))

;;; ─── Class-like parsing (trait/interface/enum) ───────────────────────────

(defun %php-parse-classlike (stream known-vars &key enum-p kind)
  "Parse trait/interface/enum as ast-defclass-style declarations."
  (multiple-value-bind (name-tok rest) (php-expect :T-IDENT stream)
    (let* ((class-name (php-ident-sym
                        (php-resolve-qualified-name
                         (php-tok-value name-tok) :class)))
           (current rest)
           (slots nil)
           (enum-cases nil)
           (enum-type nil)
           (supers nil))
      (when enum-p
        (multiple-value-bind (parsed-type after-type)
            (%php-parse-enum-backing-type current)
          (setf enum-type parsed-type
                current after-type)))
      (multiple-value-bind (parsed-supers after-supers)
          (%php-parse-class-superclasses current)
        (setf supers parsed-supers
              current after-supers))
      (setf current (%php-consume-expected :T-LBRACE current))
      (loop
        (setf current (php-skip-semis current))
        (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
          (return))
        (multiple-value-bind (attributes after-attributes) (%php-parse-attributes current)
          (if (and enum-p (%php-keyword-p after-attributes :case))
              (progn
                (setf current after-attributes)
                (multiple-value-bind (slot rest2 case-meta)
                    (%php-parse-enum-case current known-vars class-name enum-type attributes)
                  (push slot slots)
                  (push case-meta enum-cases)
                  (setf current rest2)))
              (multiple-value-bind (slot rest2 extra-slots)
                  (%php-parse-class-body-member current known-vars)
                (when slot
                  ;; Enum methods are stored CLASS-allocated (on the enum class
                  ;; object) so $case->method() resolves through the case's
                  ;; __class__ link; they remain instance methods — $this (= the
                  ;; case) is still prepended because they are not `static'.
                  (when (and enum-p (ast-slot-def-p slot)
                             (ast-defun-p (ast-slot-initform slot)))
                    (setf (ast-slot-allocation slot) :class))
                  (push slot slots))
                ;; Constructor property promotion generates extra property slots.
                (dolist (es extra-slots) (push es slots))
                (setf current rest2)))))
      (let* ((slots-rev (nreverse slots))
             (defclass (make-ast-defclass :name class-name
                                          :superclasses supers
                                          :slots slots-rev
                                          :php-kind (or kind (and enum-p :enum))
                                          :php-enum-type enum-type
                                          :php-enum-cases (nreverse enum-cases))))
        ;; Register trait methods for compile-time application (mirrors parser-trait.lisp).
        (when (eq kind :trait)
          (setf (gethash (string-upcase (symbol-name class-name)) *php-trait-registry*)
                slots-rev))
        (unless (eq kind :trait)
          (%php-record-class-trait-uses class-name slots-rev))
        (values
         ;; For enums, follow the class def with a call that links each case
         ;; singleton to the class (__class__) so method dispatch works.
         (if enum-p
             (make-ast-progn
              :forms (list defclass
                           (%php-call 'cl-cc/php::%php-enum-finalize
                                      (make-ast-var :name class-name))))
             defclass)
         (%php-consume-expected :T-RBRACE current)
         known-vars)))))

;;; ─── Use/import parsing helpers ──────────────────────────────────────────

(defun %php-use-kind (stream)
  "Return use kind and stream after optional function/const qualifier."
  (cond ((%php-keyword-p stream :function) (values :function (cdr stream)))
        ((%php-keyword-p stream :const) (values :const (cdr stream)))
        (t (values :class stream))))

(defun %php-optional-use-kind (stream)
  "Return optional group-use kind qualifier and stream after it."
  (cond ((%php-keyword-p stream :function) (values :function (cdr stream)))
        ((%php-keyword-p stream :const) (values :const (cdr stream)))
        (t (values nil stream))))

(defun %php-parse-use-alias (stream)
  "Parse optional `as Alias` and return alias/rest."
  (if (%php-keyword-p stream :as)
      (multiple-value-bind (alias-name rest) (php-parse-qualified-name (cdr stream))
        (values alias-name rest))
      (values nil stream)))

(defun %php-make-import (kind name alias)
  "Build a PHP import descriptor plist."
  (list :type kind :name name :alias alias))

(defun %php-join-qualified-prefix (prefix name)
  "Join import PREFIX and NAME with a PHP namespace separator."
  (cond ((or (null prefix) (string= prefix "")) name)
        ((or (null name) (string= name "")) prefix)
        ((char= (char prefix (1- (length prefix))) #\\) (concatenate 'string prefix name))
        (t (format nil "~A\\~A" prefix name))))

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

(defun %php-declare-body-ast (forms)
  "Return the AST node representing a declare body form list."
  (cond ((rest forms) (make-ast-progn :forms forms))
        ((first forms))
        (t (make-ast-progn :forms nil))))

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
