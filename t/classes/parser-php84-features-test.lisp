(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  (it-sequential "%php-mark-all-props-readonly adds :readonly-p to instance property slot-defs."
(let* ((prop (cl-cc/ast:make-ast-slot-def :name 'x :allocation :instance))
         (marked (cl-cc/php/classes:%php-mark-all-props-readonly (list prop)))
         (slot (first marked)))
    (expect (getf (cl-cc/ast:ast-imports slot) :readonly-p) :to-be-truthy)))
  (it-sequential "%php-mark-all-props-readonly does not modify :class allocation slots (constants/statics)."
(let* ((const (cl-cc/ast:make-ast-slot-def :name 'x :allocation :class))
         (marked (cl-cc/php/classes:%php-mark-all-props-readonly (list const)))
         (slot (first marked)))
    (expect (getf (cl-cc/ast:ast-imports slot) :readonly-p) :to-be-falsy)))
  (it-sequential "%php-lower-property-with-hooks with only a getter produces a __get_ method."
(let* ((getter-body (cl-cc/ast:make-ast-return-from :name nil
                                                  :value (cl-cc/ast:make-ast-int :value 1)))
         (prop-sym    (intern "NAME" :cl-cc))
         (methods     (cl-cc/php/classes:%php-lower-property-with-hooks
                       prop-sym getter-body nil 'myclass))
         (names       (mapcar (lambda (m) (symbol-name (cl-cc/ast:ast-defun-name m))) methods)))
    (expect (find "__GET_NAME" names :test #'string=) :to-be-truthy)))
  (it-sequential "%php-lower-property-with-hooks with only a setter produces a __set_ method."
(let* ((setter-body (cl-cc/ast:make-ast-quote :value nil))
         (prop-sym    (intern "NAME" :cl-cc))
         (methods     (cl-cc/php/classes:%php-lower-property-with-hooks
                       prop-sym nil setter-body 'myclass))
         (names       (mapcar (lambda (m) (symbol-name (cl-cc/ast:ast-defun-name m))) methods)))
    (expect (find "__SET_NAME" names :test #'string=) :to-be-truthy)))
  (it-sequential "%php-lower-property-with-hooks with get and set produces two methods."
(let* ((getter-body (cl-cc/ast:make-ast-int :value 1))
         (setter-body (cl-cc/ast:make-ast-quote :value nil))
         (prop-sym    (intern "TITLE" :cl-cc))
         (methods     (cl-cc/php/classes:%php-lower-property-with-hooks
                       prop-sym getter-body setter-body 'myclass)))
    (expect (= 2 (length methods)) :to-be-truthy)))
  (it-sequential "Class property hooks parse through the class parser and add accessor slots."
(let* ((ast (%php-first
               "<?php class User { public string $name { get => $this->name; set($value) => $value; } }"))
         (slots (cl-cc/ast:ast-defclass-slots ast))
         (slot-names (mapcar (lambda (slot)
                               (symbol-name (cl-cc/ast:ast-slot-name slot)))
                             slots)))
    (expect (member "NAME" slot-names :test #'string=) :to-be-truthy)
    (expect (member "__GET_NAME" slot-names :test #'string=) :to-be-truthy)
    (expect (member "__SET_NAME" slot-names :test #'string=) :to-be-truthy)))
  (it-sequential "%php-parse-asymmetric-visibility parses public private(set) and returns two keywords."
(let* ((pub-tok  (list :type :T-KEYWORD :value :public))
         (priv-tok (list :type :T-KEYWORD :value :private))
         (lparen   (list :type :T-LPAREN  :value "("))
         (set-tok  (list :type :T-IDENT   :value "set"))
         (rparen   (list :type :T-RPAREN  :value ")"))
         (stream   (list pub-tok priv-tok lparen set-tok rparen)))
    (multiple-value-bind (outer inner _rest)
        (cl-cc/php/classes:%php-parse-asymmetric-visibility stream)
      (declare (ignore _rest))
      (expect outer :to-be :public)
      (expect inner :to-be :private))))
  (it-sequential "%php-parse-asymmetric-visibility returns nil inner when only one modifier."
(let* ((pub-tok (list :type :T-KEYWORD :value :public))
         (ident   (list :type :T-IDENT   :value "x"))
         (stream  (list pub-tok ident)))
    (multiple-value-bind (outer inner _rest)
        (cl-cc/php/classes:%php-parse-asymmetric-visibility stream)
      (declare (ignore _rest))
      (expect outer :to-be :public)
      (expect inner :to-be-null))))
  (it-sequential "Class properties preserve PHP 8.4 asymmetric set visibility metadata."
(let* ((ast (%php-first
               "<?php class User { public private(set) string $id; }"))
         (slot (first (cl-cc/ast:ast-defclass-slots ast)))
         (imports (cl-cc/ast:ast-imports slot)))
    (expect (getf imports :php-set-visibility) :to-be :private)
    (expect (member :public (getf imports :php-modifiers) :test #'eq) :to-be-truthy)))
  (it-sequential "PHP 8.5 static properties preserve asymmetric set visibility metadata."
    (dolist (case '(("<?php class Config { final public static private(set) string $name; }"
                     :private)
                    ("<?php class Config { final public static protected(set) string $name; }"
                     :protected)))
      (let* ((ast (%php-first (first case)))
             (slot (first (cl-cc/ast:ast-defclass-slots ast)))
             (imports (cl-cc/ast:ast-imports slot))
             (modifiers (getf imports :php-modifiers)))
        (expect (cl-cc/ast:ast-slot-allocation slot) :to-be :class)
        (expect (getf imports :php-set-visibility) :to-be (second case))
        (expect (member :final modifiers :test #'eq) :to-be-truthy)
        (expect (member :public modifiers :test #'eq) :to-be-truthy)
        (expect (member :static modifiers :test #'eq) :to-be-truthy))))
  (it-sequential "PHP 8.5 constructor promotion preserves final property metadata."
(let* ((ast (%php-first
               "<?php class Token { public function __construct(final string $id) {} }"))
         (slots (cl-cc/ast:ast-defclass-slots ast))
         (slot (find-if (lambda (candidate)
                           (string= "ID" (symbol-name (cl-cc/ast:ast-slot-name candidate))))
                        slots)))
    (expect slot :to-be-truthy)
    (let* ((imports (cl-cc/ast:ast-imports slot))
           (modifiers (getf imports :php-modifiers)))
      (expect (cl-cc/ast:ast-slot-allocation slot) :to-be :instance)
      (expect (member :final modifiers :test #'eq) :to-be-truthy))))
  (it-sequential "An enum with a method body contains the method as a slot-def."
    (dolist (spec (list
                   (list "<?php enum Status: int { case Draft = 0; public function label(): string { return 'Draft'; } } function afterEnum() {}"
                         :enum "LABEL")
                   (list "<?php class User { public string $name; }"
                         :class "NAME")))
      (destructuring-bind (source expected-kind expected-slot-name) spec
        (let* ((form  (%php-first source))
               ;; An enum now lowers to (progn defclass (link-cases)); unwrap the defclass when present.
               (ast   (if (cl-cc/ast:ast-progn-p form) (first (cl-cc/ast:ast-progn-forms form)) form))
               (slots (cl-cc/ast:ast-defclass-slots ast))
               (slot-names (mapcar (lambda (s) (symbol-name (cl-cc/ast:ast-slot-name s))) slots)))
          (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be expected-kind)
          (expect (member expected-slot-name slot-names :test #'string=) :to-be-truthy)))))
  (it-sequential "function f(Logger $l = new FileLogger()) parses default value as PHP new lowering."
;; PHP 8.1 allows `new ClassName()` as a default parameter value.
  ;; `new` lowers to a let that allocates the instance, conditionally runs
  ;; __construct, and returns the instance.
  (let* ((ast (%php-first
               "<?php function process(Logger $logger = new FileLogger()) { return $logger; }"))
         (optionals (cl-cc/ast:ast-defun-optional-params ast))
         (default-ast (second (first optionals)))
         (instance-ast (cdr (first (cl-cc/ast:ast-let-bindings default-ast)))))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (= 1 (length optionals)) :to-be-truthy)
    (expect (cl-cc/ast:ast-let-p default-ast) :to-be-truthy)
    (expect (cl-cc/ast:ast-make-instance-p instance-ast) :to-be-truthy)
    (expect (symbol-name (cl-cc/ast:ast-var-name
                                  (cl-cc/ast:ast-make-instance-class instance-ast))) :to-equal "FILELOGGER"))))
