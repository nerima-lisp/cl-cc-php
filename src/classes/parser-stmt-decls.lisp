;;;; parser-stmt-decls.lisp — PHP Parser: catch/enum/class-like, use-import, and declare parsing
;;;; helpers

(in-package #:cl-cc/php/classes)

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
  (%php-call '%php-enum-make-case
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
                           (%php-call '%php-enum-finalize
                                      (make-ast-var :name class-name))))
             defclass)
         (%php-consume-expected :T-RBRACE current)
         known-vars)))))

(in-package #:cl-cc/php/classes)

(define-php-stmt-parser :enum (rest known-vars) (%php-parse-classlike rest known-vars :enum-p t))

(in-package #:cl-cc/php/classes)

(in-package #:cl-cc/php/classes)

(define-php-stmt-parser :trait (rest known-vars)
  (%php-parse-classlike rest known-vars :kind :trait))
