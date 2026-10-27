;;;; parser-class.lisp — PHP class body parser and top-level parser entry point
(in-package #:cl-cc/php/classes)

(declaim (special *php-interface-registry*))

;;; ─── Class Body Parser ───────────────────────────────────────────────────────

(defun %php-parse-visibility-modifiers (stream)
  "Consume zero or more visibility/modifier keywords and return them as metadata."
  (let ((modifiers nil))
    (flet ((visibility-modifier-p (modifier)
             (member modifier '(:public :protected :private) :test #'eq))
           (set-visibility-tail-p (tail)
             (and tail
                  (eq (php-peek-type tail) :T-KEYWORD)
                  (member (php-peek-value tail) '(:private :protected) :test #'eq)
                  (cdr tail)
                  (eq (php-peek-type (cdr tail)) :T-LPAREN)
                  (cddr tail)
                  (eq (php-peek-type (cddr tail)) :T-IDENT)
                  (string-equal (php-peek-value (cddr tail)) "set")
                  (cdddr tail)
                  (eq (php-peek-type (cdddr tail)) :T-RPAREN))))
      (loop while (and stream
                       (let ((type (php-peek-type stream))
                             (val  (php-peek-value stream)))
                         (or (and (eq type :T-KEYWORD)
                                  (member val '(:public :private :protected :static
                                                :abstract :final :readonly)))
                             ;; `static` lexes as a T-TYPE because it is also the
                             ;; `static` return-type keyword.  In modifier position
                             ;; it is the static-member modifier — accept it here so
                             ;; static properties/methods are flagged :static rather
                             ;; than parsed with a bogus `static` type hint and left
                             ;; instance-allocated (which broke C::$prop and C::m()).
                             (and (eq type :T-TYPE) (eq val :STATIC)))))
          do (let ((type (php-peek-type stream))
                   (val  (php-peek-value stream)))
               (cond
                 ;; PHP 8.5 static asymmetric property visibility permits other
                 ;; modifiers between the outer visibility and private(set), e.g.
                 ;; public static private(set) Type $prop;
                 ((and (visibility-modifier-p val)
                       (set-visibility-tail-p stream)
                       (some #'visibility-modifier-p modifiers))
                  (push (cons :set-visibility val) modifiers)
                  (setf stream (cdr (cdddr stream))))
                 ;; PHP 8.4 asymmetric property visibility:
                 ;; public private(set) Type $prop;
                 ((and (eq type :T-KEYWORD)
                       (visibility-modifier-p val)
                       (set-visibility-tail-p (cdr stream)))
                  (push val modifiers)
                  (push (cons :set-visibility (php-peek-value (cdr stream))) modifiers)
                  (setf stream (cdr (cddddr stream))))
                 (t
                  (push val modifiers)
                  (setf stream (cdr stream)))))))
    (values (nreverse modifiers) stream)))

(defun %php-slot-metadata (modifiers &key class-constant-p attributes target-type)
  "Build AST node metadata for PHP class members."
  (let ((set-visibility (cdr (find :set-visibility modifiers
                                   :key (lambda (modifier)
                                          (when (consp modifier) (car modifier)))
                                   :test #'eq)))
        (plain-modifiers (remove-if #'consp modifiers)))
  (append (when plain-modifiers (list :php-modifiers plain-modifiers))
          (when set-visibility (list :php-set-visibility set-visibility))
          (when class-constant-p (list :php-class-constant t))
          (%php-attribute-metadata attributes target-type))))

(defun %php-parse-class-constant (stream modifiers known-vars attributes)
  "Parse const [TYPE] NAME = VALUE[, NAME = VALUE]*; as class-scoped slots."
  (declare (ignore known-vars))
  (let ((current (cdr stream))
        (constant-type nil)
        (slots nil))
    (multiple-value-bind (parsed-type after-type) (php-parse-type-annotation current)
      (when (and parsed-type (eq (php-peek-type after-type) :T-IDENT))
        (setf constant-type parsed-type
              current after-type)))
    (loop
      (multiple-value-bind (name-tok rest) (php-expect :T-IDENT current)
        (let ((initform nil))
          (setf current rest)
          (when (and current (eq (php-peek-type current) :T-OP)
                     (equal "=" (php-peek-value current)))
            (multiple-value-bind (expr rest2 _) (php-parse-expr (cdr current) nil)
              (declare (ignore _))
              (setf initform expr
                    current rest2)))
          (push (make-ast-slot-def :name (php-ident-sym (php-tok-value name-tok))
                                   :type constant-type
                                   :initform initform
                                   :allocation :class
                                   :imports (%php-slot-metadata modifiers
                                                               :class-constant-p t
                                                               :attributes attributes
                                                               :target-type :constant))
                slots)))
      (unless (and current (eq (php-peek-type current) :T-COMMA))
        (return))
      (when attributes
        (error
         "PHP parse error: attributes on grouped const declarations require exactly one constant"))
      (setf current (cdr current)))
    (let ((ordered-slots (nreverse slots)))
      (values (first ordered-slots)
              (php-skip-semis current)
              (rest ordered-slots)))))

(defun %php-promoted-param-assignments (param-attributes)
  "Build (ast-set-slot-value $this->prop $param) nodes for each promoted param.
PARAM-ATTRIBUTES is the :php-param-attributes plist value from an ast-defun."
  (loop for attr-plist in param-attributes
        for param = (car attr-plist)
        when (getf (cdr attr-plist) :php-promote)
          collect (make-ast-set-slot-value
                   :object (make-ast-var :name (php-var-sym "$this"))
                   :slot   (php-ident-sym (symbol-name param))
                   :value  (make-ast-var :name param))))

(defun %php-promoted-property-slots (param-attributes)
  "Build ast-slot-def nodes declaring each promoted param as a class property.
PHP 8.0 constructor promotion both declares AND initializes the property."
  (loop for attr-plist in param-attributes
        for param = (car attr-plist)
        for mods = (getf (cdr attr-plist) :php-promote)
        when mods
          collect (make-ast-slot-def
                   :name      (php-ident-sym (symbol-name param))
                   :initform  (make-ast-quote :value +php-null+)
                   :allocation (%php-member-slot-allocation mods)
                   :imports   (%php-slot-metadata mods :target-type :property))))

(defun %php-parse-class-body-member (stream known-vars &optional class-name)
  "Parse one class body member: a property declaration or a method definition.
Returns (values slot-def-or-nil remaining-stream extra-slots).
EXTRA-SLOTS is a list of additional slots to inject (used for constructor promotion)."
  (multiple-value-bind (attributes stream) (%php-parse-attributes stream)
  (multiple-value-bind (modifiers stream) (%php-parse-visibility-modifiers stream)
  (let ((stream (php-skip-semis stream)))
    (cond
      ;; $var [= default];  — direct property
      ((eq (php-peek-type stream) :T-VAR)
       (multiple-value-bind (slots rest)
           (%php-parse-property-slot-with-hooks stream modifiers attributes class-name)
         (values (first slots) rest (rest slots))))
      ;; type $var;  — typed property, including nullable/union/intersection/DNF types
      ((or (%php-type-atom-token-p stream)
           (eq (php-peek-type stream) :T-LPAREN)
           (eq (php-peek-type stream) :T-NULLABLE))
        (multiple-value-bind (property-type rest) (php-parse-type-annotation stream)
          (if (and property-type (eq (php-peek-type rest) :T-VAR))
              (multiple-value-bind (slots rest2)
                  (%php-parse-property-slot-with-hooks stream modifiers attributes class-name)
                (values (first slots) rest2 (rest slots)))
              (values nil rest))))
      ;; const [TYPE] NAME = value; — class constants as class-scoped metadata slots.
       ((and (eq (php-peek-type stream) :T-KEYWORD)
               (eq (php-peek-value stream) :const))
        (%php-parse-class-constant stream modifiers known-vars attributes))
       ;; use TraitName[, OtherTrait] [{ insteadof/as block }]; — trait use with
       ;; optional conflict-resolution block, inside class-like bodies.
       ;; Delegate to the full use-trait parser (defined in parser-trait.lisp)
       ;; that handles { insteadof/as } blocks.  The `use` keyword was already
       ;; consumed by the caller that found :use in the token stream, but here
       ;; we are still at the `use` token — strip it before dispatching.
       ((and (eq (php-peek-type stream) :T-KEYWORD)
             (eq (php-peek-value stream) :use))
        (multiple-value-bind (slot rest kv)
            (%php-parse-use-trait-stmt (cdr stream) known-vars)
          (declare (ignore kv))
          (values slot rest)))
      ;; function name(...) { }  — method
      ((and (eq (php-peek-type stream) :T-KEYWORD)
            (eq (php-peek-value stream) :function))
        (multiple-value-bind (method-ast rest _) (php-parse-statement stream known-vars)
           (declare (ignore _))
           (%php-attach-attributes-to-node method-ast attributes :method)
           ;; Instance methods receive an implicit $this first parameter; the call
           ;; site ($o->m(args)) passes the receiver as the first argument. Static
           ;; methods have no receiver, so they are left as-is.
           (when (and method-ast
                      (ast-defun-p method-ast)
                      (not (member :static modifiers :test #'eq)))
             (setf (ast-defun-params method-ast)
                   (cons (php-var-sym "$this") (ast-defun-params method-ast))))
           ;; Constructor property promotion (PHP 8.0+): inject $this->prop = $param;
           ;; at the top of __construct for each param tagged :php-promote.
           (let (promoted-slots)
             (when (and method-ast
                        (ast-defun-p method-ast)
                        (eq (ast-defun-name method-ast) (php-ident-sym "__construct")))
               (let* ((attrs (getf (ast-defun-declarations method-ast) :php-param-attributes))
                      (promos (%php-promoted-param-assignments attrs)))
                 (when promos
                   (setf (ast-defun-body method-ast)
                         (append promos (ast-defun-body method-ast)))
                   (setf promoted-slots (%php-promoted-property-slots attrs)))))
             (values (when method-ast
                       ;; Store full ast-defun in slot-def initform to preserve method body.
                       ;; Static methods are class-allocated so their bound closure lives on
                       ;; the class object itself — C::method() then resolves via slot-value
                       ;; on the class (the same path class constants already use).  Instance
                       ;; methods stay :instance so each object carries its own closure.
                       (make-ast-slot-def :name (ast-defun-name method-ast)
                                          :initform method-ast
                                          :allocation (%php-member-slot-allocation modifiers)
                                          :imports (%php-slot-metadata modifiers
                                                                       :attributes attributes
                                                                       :target-type :method)))
                     rest
                     promoted-slots))))
      ;; Unknown class-body syntax must not be silently discarded. Silent skip
      ;; made unsupported PHP look successfully parsed while losing source.
      (t (error "PHP unsupported feature in class body near token ~S" (php-peek stream))))))))

(defun %php-parse-class-superclasses (stream)
  "Consume optional 'extends ClassName' and 'implements A, B, ...' clauses.
Returns (values superclass-list remaining-stream)."
  (let ((supers nil) (current stream))
    (when (and current (eq (php-peek-type current) :T-KEYWORD)
               (eq (php-peek-value current) :extends))
      (setf current (cdr current))
      (multiple-value-bind (super-name rest) (php-parse-qualified-name current)
        (push (php-ident-sym (php-resolve-qualified-name super-name :class)) supers)
        (setf current rest)))
    (when (and current (eq (php-peek-type current) :T-KEYWORD)
               (eq (php-peek-value current) :implements))
      (setf current (cdr current))
      (loop
        (multiple-value-bind (interface-name rest) (php-parse-qualified-name current)
          (push (php-ident-sym (php-resolve-qualified-name interface-name :class)) supers)
          (setf current rest))
        (unless (and current (eq (php-peek-type current) :T-COMMA))
          (return))
        (setf current (cdr current))))
    (values (nreverse supers) current)))

(defun %php-readonly-class-slots (slots)
  "Mark instance property slots as readonly for PHP 8.2 readonly classes."
  (mapcar (lambda (slot)
            (if (and (ast-slot-def-p slot)
                     (eq (ast-slot-allocation slot) :instance)
                     (not (ast-defun-p (ast-slot-initform slot))))
                (let* ((copy (copy-structure slot))
                       (imports (ast-imports copy))
                       (base-imports (loop for (key value) on imports by #'cddr
                                           unless (member key '(:php-modifiers :readonly-p)
                                                          :test #'eq)
                                             append (list key value)))
                       (modifiers (copy-list (getf imports :php-modifiers))))
                  (unless (member :readonly modifiers :test #'eq)
                    (setf modifiers (append modifiers (list :readonly))))
                  (setf (ast-imports copy)
                        (append base-imports
                                (list :php-modifiers modifiers
                                      :readonly-p t)))
                  copy)
                slot))
          slots))

(defun %php-parse-class-decl (rest known-vars &key readonly-p)
  (multiple-value-bind (name-tok rest) (php-expect :T-IDENT rest)
    (let ((class-name (php-ident-sym
                       (php-resolve-qualified-name (php-tok-value name-tok) :class))))
      (multiple-value-bind (supers rest) (%php-parse-class-superclasses rest)
        (let ((current (%php-consume-expected :T-LBRACE rest))
              (slots nil)
              ;; Expose the class + parents to expression parsing so self:: /
              ;; static:: / parent:: inside method bodies resolve correctly.
              (*php-current-class* class-name)
              (*php-current-supers* supers))
          (loop
            (setf current (php-skip-semis current))
            (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
              (return))
            (multiple-value-bind (slot rest2 extra-slots)
                (%php-parse-class-body-member current known-vars class-name)
              (when slot (push slot slots))
              (dolist (es extra-slots) (push es slots))
              (setf current rest2)))
          (setf slots (nreverse slots))
          (when readonly-p
            (setf slots (%php-readonly-class-slots slots)))
          (%php-record-class-trait-uses class-name slots)
          (values (make-ast-defclass :name class-name
                                      :superclasses supers
                                      :slots slots
                                      :php-kind :class)
                  (%php-consume-expected :T-RBRACE current)
                  known-vars))))))

(define-php-stmt-parser :class (rest known-vars)
  (%php-parse-class-decl rest known-vars))

(define-php-stmt-parser :readonly (rest known-vars)
  (unless (and rest
               (eq (php-peek-type rest) :T-KEYWORD)
               (eq (php-peek-value rest) :class))
    (error "PHP readonly modifier is only supported before class declarations near token ~S"
           (php-peek rest)))
  (%php-parse-class-decl (cdr rest) known-vars :readonly-p t))

(define-php-stmt-parser :abstract (rest known-vars)
  ;; `abstract class Foo { abstract function m(): T; ... }' — the leading `abstract'
  ;; here is the CLASS-level modifier and has no registered top-level statement
  ;; parser of its own, unlike :READONLY above. Member-level `abstract function ...;'
  ;; inside a class BODY is already handled by %PHP-PARSE-VISIBILITY-MODIFIERS
  ;; (called from %PHP-PARSE-CLASS-BODY-MEMBER); this is specifically for the
  ;; keyword appearing before `class' itself.
  (unless (and rest
               (eq (php-peek-type rest) :T-KEYWORD)
               (eq (php-peek-value rest) :class))
    (error "PHP abstract modifier is only supported before class declarations near token ~S"
           (php-peek rest)))
  (%php-parse-class-decl (cdr rest) known-vars))

(define-php-stmt-parser :final (rest known-vars)
  ;; `final class Foo { ... }' — same gap as :ABSTRACT above and fixed the same way: the
  ;; leading `final' is the CLASS-level modifier and had no registered top-level statement
  ;; parser of its own. As with :ABSTRACT, this only makes the class parse; nothing tracks
  ;; "is this class final" past parsing, so extending a final class is not rejected either
  ;; — the same class of enforcement gap as :ABSTRACT's un-rejected instantiation and
  ;; `readonly`'s un-rejected reassignment (see the release notes), not attempted here.
  (unless (and rest
               (eq (php-peek-type rest) :T-KEYWORD)
               (eq (php-peek-value rest) :class))
    (error "PHP final modifier is only supported before class declarations near token ~S"
           (php-peek rest)))
  (%php-parse-class-decl (cdr rest) known-vars))

;;; ─── Interface Statement Parser (overrides parser-stmt entry) ───────────────

(define-php-stmt-parser :interface (rest known-vars)
  "%php-parse-interface-decl handles the full interface syntax including
multiple-extends and abstract method signatures."
  (%php-parse-interface-decl rest known-vars))
;;; ─── Statement sub-parsers ──────────────────────────────────────────────────

(defun %parse-php-class-body-members (ts)
  "Parse class member declarations until '}'. Returns list of CST nodes (reversed)."
  (let ((members nil))
    (loop
      (php-ts-skip-semis ts)
      (when (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE)) (return))
      (loop while (and (not (php-ts-at-end-p ts))
                       (php-ts-at-type-p ts :T-KEYWORD)
                       (member (php-ts-peek-value ts)
                               '(:public :private :protected :static
                                 :abstract :final :readonly)))
            do (php-ts-advance ts))
      (cond
        ((php-ts-at-type-p ts :T-VAR)
         (push (%php-tok-to-cst (php-ts-advance ts)) members)
         (php-ts-skip-semis ts))
        ((member (php-ts-peek-type ts) '(:T-TYPE :T-NULLABLE))
         (php-ts-advance ts)
         (when (member (php-ts-peek-type ts) '(:T-TYPE :T-IDENT)) (php-ts-advance ts))
         (when (php-ts-at-type-p ts :T-VAR)
           (push (%php-tok-to-cst (php-ts-advance ts)) members))
         (php-ts-skip-semis ts))
        ((and (php-ts-at-type-p ts :T-KEYWORD) (php-ts-at-value-p ts :function))
         (let ((method (php-cst-parse-statement ts)))
           (when method (push method members))))
        (t (php-ts-advance ts))))
    members))

(defun %parse-php-class-def (ts kw-tok)
"Parse `class Name [extends Base] [implements ...] { members }` starting after the 'class' keyword."
  (let ((name-tok (php-ts-expect ts :T-IDENT nil "class name"))
        (extends nil))
    (when (and (not (php-ts-at-end-p ts))
               (php-ts-at-type-p ts :T-KEYWORD)
               (php-ts-at-value-p ts :extends))
      (php-ts-advance ts)
      (let ((super-tok (php-ts-expect ts :T-IDENT nil "superclass")))
        (when super-tok (setf extends (%php-tok-to-cst super-tok)))))
    (when (and (not (php-ts-at-end-p ts))
               (php-ts-at-type-p ts :T-KEYWORD)
               (php-ts-at-value-p ts :implements))
      (php-ts-advance ts)
      (loop (php-ts-expect ts :T-IDENT nil "interface")
            (unless (php-ts-at-type-p ts :T-COMMA) (return))
            (php-ts-advance ts)))
    (php-ts-expect ts :T-LBRACE nil "class body")
    (let ((members (%parse-php-class-body-members ts)))
      (php-ts-expect ts :T-RBRACE nil "class body")
      (%php-cst-interior :class-def
                         (append (list (%php-tok-to-cst kw-tok))
                                 (when name-tok (list (%php-tok-to-cst name-tok)))
                                 (when extends (list extends))
                                 (nreverse members))))))

(defun %parse-php-class-def-stmt (ts)
  (%parse-php-class-def ts (php-ts-advance ts)))

(defun %parse-php-classlike-stmt (ts)
  (let ((kw-tok (php-ts-advance ts))
        (children nil))
    (loop while (and (not (php-ts-at-end-p ts))
                     (not (php-ts-at-type-p ts :T-LBRACE)))
          do (push (%php-tok-to-cst (php-ts-advance ts)) children))
    (php-ts-expect ts :T-LBRACE nil "class-like")
    (loop until (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE))
          do (push (%php-tok-to-cst (php-ts-advance ts)) children))
    (php-ts-expect ts :T-RBRACE nil "class-like")
    (%php-cst-interior :class-like (cons (%php-tok-to-cst kw-tok) (nreverse children)))))

(progn)

(defun php-cst-parse-new (ts)
  "Parse 'new ClassName(args...)'."
  (let ((new-tok (php-ts-advance ts)))
    (let ((class-tok (php-ts-expect ts :T-IDENT nil "new")))
      (let ((args (if (php-ts-at-type-p ts :T-LPAREN)
                      (php-cst-parse-arglist ts)
                      nil)))
        (%php-cst-interior :new
                           (append (list (%php-tok-to-cst new-tok))
                                   (when class-tok (list (%php-tok-to-cst class-tok)))
                                   args))))))

(eval-when (:load-toplevel :execute)
  (register-php-cst-keyword-expression-parser :new #'php-cst-parse-new)
  (register-php-cst-keyword-expression-parser
   :clone #'%PARSER-PHP-CST-PARSE-UNARY-KEYWORD-EXPRESSION)
  (register-php-cst-keyword-statement-parser :class #'%parse-php-class-def-stmt)
  (register-php-cst-keyword-statement-parser :trait #'%parse-php-classlike-stmt)
  (register-php-cst-keyword-statement-parser :interface #'%parse-php-classlike-stmt)
  (register-php-cst-keyword-statement-parser :enum #'%parse-php-classlike-stmt))

(eval-when (:load-toplevel :execute) (register-php-parameter-modifier-parser #'%php-parse-visibility-modifiers))
