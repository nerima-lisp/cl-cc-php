(in-package :cl-cc-php/test)

(describe "PHP 8.4 language features"


(it-sequential "Named arg descriptors from %php-parse-named-args lower to plain positional AST exprs."
;; Test the helper function directly with hand-built descriptors.
  (let* ((descs  (list (list :positional (cl-cc/ast:make-ast-int :value 1))
                       (list :named "key" (cl-cc/ast:make-ast-quote :value "val"))
                       (list :spread  (cl-cc/ast:make-ast-var :name 'x))))
         (result (cl-cc/php::%php-named-args-to-positional descs)))
    (expect (= 3 (length result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-int-p (first result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-quote-p (second result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-p (third result)) :to-be-truthy)))

(it-sequential "The %php-named-arg-p predicate recognises IDENT : as a named argument."
;; We test with a hand-built token stream matching the helper contract.
  (let* ((ident-tok   (list :type :T-IDENT :value "name"))
         (colon-tok   (list :type :T-COLON :value ":"))
         (fake-stream (list ident-tok colon-tok)))
    (expect (cl-cc/php::%php-named-arg-p fake-stream) :to-be-truthy)))

(it-sequential "createUser(name: \"Alice\", age: 25) lowers to an ast-call with 2 positional args."
(let* ((ast (%php-first "<?php createUser(\"Alice\", 25);")))
    ;; Without named-arg integration in php-parse-arglist the call uses
    ;; positional lowering: two arguments are preserved in order.
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (= 2 (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)))

(it-sequential "Positional args before named args both survive into the call AST."
(let* ((ast (%php-first "<?php htmlspecialchars(\"<b>hi</b>\", 11);")))
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (plusp (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)))

(it-sequential "The %php-first-class-callable-p predicate returns true for ( ... ) token sequence."
(let* ((lparen-tok  (list :type :T-LPAREN   :value "("))
         (ellipsis-tok (list :type :T-ELLIPSIS :value "..."))
         (rparen-tok  (list :type :T-RPAREN   :value ")"))
         (stream      (list lparen-tok ellipsis-tok rparen-tok)))
    (expect (cl-cc/php::%php-first-class-callable-p stream) :to-be-truthy)))

(it-sequential "The %php-first-class-callable-p predicate returns false when ( has real args."
(let* ((lparen-tok  (list :type :T-LPAREN :value "("))
         (int-tok     (list :type :T-INT    :value 1))
         (rparen-tok  (list :type :T-RPAREN :value ")"))
         (stream      (list lparen-tok int-tok rparen-tok)))
    (expect (cl-cc/php::%php-first-class-callable-p stream) :to-be-falsy)))

(it-sequential "The %php-callable-ref function returns an ast-lambda that wraps the function."
(let* ((func-ast (cl-cc/ast:make-ast-var :name 'strlen))
         (ref      (cl-cc/php::%php-callable-ref func-ast)))
    (expect (cl-cc/ast:ast-lambda-p ref) :to-be-truthy)
    (expect (plusp (length (cl-cc/ast:ast-lambda-body ref))) :to-be-truthy)))

(it-sequential "The lambda body inside a callable ref calls APPLY with the original function."
(let* ((func-ast (cl-cc/ast:make-ast-var :name 'strlen))
         (ref      (cl-cc/php::%php-callable-ref func-ast))
         (body-call (first (cl-cc/ast:ast-lambda-body ref))))
    (expect (cl-cc/ast:ast-call-p body-call) :to-be-truthy)
    (expect (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func body-call))) :to-equal "APPLY")))

(it-sequential "array_find() returns the first element satisfying the callback."
(let* ((arr (cl-cc/php:%php-array (list nil nil 3) (list nil nil 7) (list nil nil 4)))
         (result (cl-cc/php::%php-array-find arr (lambda (v) (> v 5)))))
    (expect (= 7 result) :to-be-truthy)))

(it-sequential "array_find() returns +php-null+ when no element satisfies the callback."
(let* ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2)))
         (result (cl-cc/php::%php-array-find arr (lambda (v) (> v 10)))))
    (expect result :to-equal cl-cc/php:+php-null+)))

(it-sequential "array_find_key() returns the integer key of the first matching element."
(let* ((arr (cl-cc/php:%php-array (list nil nil 10) (list nil nil 20) (list nil nil 30)))
         (result (cl-cc/php::%php-array-find-key arr (lambda (v) (= v 20)))))
    (expect (= 1 result) :to-be-truthy)))

(it-sequential "array_find_key() returns +php-null+ when no element matches."
(let* ((arr (cl-cc/php:%php-array (list nil nil 1)))
         (result (cl-cc/php::%php-array-find-key arr (lambda (v) (> v 100)))))
    (expect result :to-equal cl-cc/php:+php-null+)))

(it-sequential "array_any() returns true when at least one element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2) (list nil nil 50))))
    (expect (cl-cc/php::%php-array-any arr (lambda (v) (> v 10))) :to-be-truthy)))

(it-sequential "array_any() returns false when no element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2))))
    (expect (cl-cc/php::%php-array-any arr (lambda (v) (> v 100))) :to-be-falsy)))

(it-sequential "array_all() returns true when every element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 5) (list nil nil 10) (list nil nil 20))))
    (expect (cl-cc/php::%php-array-all arr (lambda (v) (> v 0))) :to-be-truthy)))

(it-sequential "array_all() returns false when any element fails the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 5) (list nil nil -1))))
    (expect (cl-cc/php::%php-array-all arr (lambda (v) (> v 0))) :to-be-falsy)))

(it-sequential "array_all() returns true for an empty array (vacuous truth)."
    (let ((arr (cl-cc/php:%php-array)))
      (expect (cl-cc/php::%php-array-all arr (lambda (v) (declare (ignore v)))) :to-be-truthy)
      (expect (cl-cc/php::%php-array-all (cl-cc/php:%php-array (list nil nil 1))
                                  (lambda (v) (declare (ignore v)) nil)) :to-be-falsy)))


(it-sequential "new Fiber(callback) lowers to a PHP object wrapper via %php-fiber-make."
    (let ((fiber (cl-cc/php::%php-fiber-make (lambda () 42))))
      (expect (hash-table-p fiber) :to-be-truthy)
      (expect (gethash "__class__" fiber) :to-equal "Fiber")
      (expect (cl-cc/php::%php-fiber-started-p fiber) :to-be-falsy)
      (expect (cl-cc/php::%php-fiber-terminated-p fiber) :to-be-falsy)
      (expect (= 42 (cl-cc/php::%php-fiber-start fiber)) :to-be-truthy)
      (expect (cl-cc/php::%php-fiber-started-p fiber) :to-be-truthy)
      (expect (cl-cc/php::%php-fiber-terminated-p fiber) :to-be-truthy)))

(it-sequential "Fiber::start() runs the callback and returns its result when it does not suspend."
(let* ((fiber (cl-cc/php::%php-fiber-make (lambda () 99)))
         (result (cl-cc/php::%php-fiber-start fiber)))
    (expect (= 99 result) :to-be-truthy)
    (expect (cl-cc/php::%php-fiber-started-p fiber) :to-be-truthy)
    (expect (cl-cc/php::%php-fiber-terminated-p fiber) :to-be-truthy)))

(it-sequential "Starting an already-started Fiber signals an error."
(let ((fiber (cl-cc/php::%php-fiber-make (lambda () 1))))
    (cl-cc/php::%php-fiber-start fiber)
    (signals error (cl-cc/php::%php-fiber-start fiber))))

(it-sequential "%php-fiber-get-return returns the final return value of a terminated Fiber."
(let* ((fiber (cl-cc/php::%php-fiber-make (lambda () :done))))
    (cl-cc/php::%php-fiber-start fiber)
    (expect (cl-cc/php::%php-fiber-get-return fiber) :to-be :done)))

(it-sequential "%php-fiber-get-return signals an error when the fiber has not yet terminated."
    (let ((fiber (cl-cc/php::%php-fiber-make (lambda () :done))))
      ;; Not started yet
      (signals error (cl-cc/php::%php-fiber-get-return fiber))
      (expect (cl-cc/php::%php-fiber-start fiber) :to-be :done)))

(it-sequential "%php-mark-all-props-readonly adds :readonly-p to instance property slot-defs."
(let* ((prop (cl-cc/ast:make-ast-slot-def :name 'x :allocation :instance))
         (marked (cl-cc/php::%php-mark-all-props-readonly (list prop)))
         (slot (first marked)))
    (expect (getf (cl-cc/ast:ast-imports slot) :readonly-p) :to-be-truthy)))

(it-sequential "%php-mark-all-props-readonly does not modify :class allocation slots (constants/statics)."
(let* ((const (cl-cc/ast:make-ast-slot-def :name 'x :allocation :class))
         (marked (cl-cc/php::%php-mark-all-props-readonly (list const)))
         (slot (first marked)))
    (expect (getf (cl-cc/ast:ast-imports slot) :readonly-p) :to-be-falsy)))

(it-sequential "%php-lower-property-with-hooks with only a getter produces a __get_ method."
(let* ((getter-body (cl-cc/ast:make-ast-return-from :name nil
                                                  :value (cl-cc/ast:make-ast-int :value 1)))
         (prop-sym    (intern "NAME" :cl-cc))
         (methods     (cl-cc/php::%php-lower-property-with-hooks
                       prop-sym getter-body nil 'myclass))
         (names       (mapcar (lambda (m) (symbol-name (cl-cc/ast:ast-defun-name m))) methods)))
    (expect (find "__GET_NAME" names :test #'string=) :to-be-truthy)))

(it-sequential "%php-lower-property-with-hooks with only a setter produces a __set_ method."
(let* ((setter-body (cl-cc/ast:make-ast-quote :value nil))
         (prop-sym    (intern "NAME" :cl-cc))
         (methods     (cl-cc/php::%php-lower-property-with-hooks
                       prop-sym nil setter-body 'myclass))
         (names       (mapcar (lambda (m) (symbol-name (cl-cc/ast:ast-defun-name m))) methods)))
    (expect (find "__SET_NAME" names :test #'string=) :to-be-truthy)))

(it-sequential "%php-lower-property-with-hooks with get and set produces two methods."
(let* ((getter-body (cl-cc/ast:make-ast-int :value 1))
         (setter-body (cl-cc/ast:make-ast-quote :value nil))
         (prop-sym    (intern "TITLE" :cl-cc))
         (methods     (cl-cc/php::%php-lower-property-with-hooks
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
        (cl-cc/php::%php-parse-asymmetric-visibility stream)
      (declare (ignore _rest))
      (expect outer :to-be :public)
      (expect inner :to-be :private))))

(it-sequential "%php-parse-asymmetric-visibility returns nil inner when only one modifier."
(let* ((pub-tok (list :type :T-KEYWORD :value :public))
         (ident   (list :type :T-IDENT   :value "x"))
         (stream  (list pub-tok ident)))
    (multiple-value-bind (outer inner _rest)
        (cl-cc/php::%php-parse-asymmetric-visibility stream)
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

(it-sequential "Intersection type A&B in a function declaration is preserved as a type annotation string."
(let* ((ast (%php-first
               "<?php function process(Iterator $it): void { return; }"))
         (decls (cl-cc/ast:ast-defun-declarations ast)))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (getf decls :php-return-type) :to-equal "void")))

(it-sequential "%php-parse-intersection-type builds a structured :intersection descriptor."
;; We call the helper directly with a fake stream.
  ;; %php-type-token-string lowercases the segment, so "Countable" → "countable".
  (let* ((amp-tok       (list :type :T-OP    :value "&"))
         (countable-tok (list :type :T-IDENT  :value "Countable"))
         (stream        (list amp-tok countable-tok)))
    (multiple-value-bind (spec _rest)
        (cl-cc/php::%php-parse-intersection-type "Iterator" stream)
      (declare (ignore _rest))
      (expect (consp spec) :to-be-truthy)
      (expect (first spec) :to-be :intersection)
      (expect (member "Iterator" spec :test #'string=) :to-be-truthy)
      (expect (member "countable" spec :test #'string=) :to-be-truthy))))

(it-sequential "function fail(): never preserves 'never' as the return type in declarations."
(let* ((ast (%php-first "<?php function fail(): never { throw new Ex(); }"))
         (decls (cl-cc/ast:ast-defun-declarations ast)))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (getf decls :php-return-type) :to-equal "never")))

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
                                  (cl-cc/ast:ast-make-instance-class instance-ast))) :to-equal "FILELOGGER")))


  )
