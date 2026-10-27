;;;; runtime-builtins-io-objects-test.lisp — src/runtime-builtins-io-objects.lisp.
;;;;
;;;; The PHP object model, type metadata, class/interface/method existence, and reflection helpers.
;;;; PHP objects are modelled as plain equal hash-tables carrying a "__class__" key, and optionally
;;;; "__parent__".

(in-package :cl-cc-php/test)

(describe
  "PHP object-model, type-metadata, and reflection builtins"
  (it-sequential
    "runtime-type-key upcases and stringifies a namespaced class name"
    (expect (cl-cc/php::%php-runtime-type-key "foo\\Bar") :to-equal "FOO\\BAR"))
  (it-sequential
    "runtime class tags register and resolve case-insensitively"
    (cl-cc/php::%php-register-runtime-class-tag "ClccTestTagClass")
    (expect
      (cl-cc/php::%php-runtime-class-tag-exists-p "ClccTestTagClass")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-runtime-class-tag-exists-p "clcctesttagclass")
      :to-be-truthy)
    (expect (cl-cc/php::%php-runtime-class-tag-exists-p "NopeTagXyz") :to-be nil))
  (it-sequential
    "runtime interface tags register and resolve"
    (cl-cc/php::%php-register-runtime-interface-tag "ClccTestIface")
    (expect
      (cl-cc/php::%php-runtime-interface-tag-exists-p "ClccTestIface")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-runtime-interface-tag-exists-p "NoIfaceXyz")
      :to-be
      nil))
  (it-sequential
    "runtime class-method registration is queryable and case-insensitive"
    (cl-cc/php::%php-register-runtime-class-methods
      "ClccTestMethodClass"
      '("foo" "bar"))
    (expect
      (cl-cc/php::%php-runtime-class-method-exists-p "ClccTestMethodClass" "foo")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-runtime-class-method-exists-p "ClccTestMethodClass" "FOO")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-runtime-class-method-exists-p "ClccTestMethodClass" "baz")
      :to-be
      nil)
    (expect
      (member
        "bar"
        (cl-cc/php::%php-runtime-class-methods "ClccTestMethodClass")
        :test
        #'string=)
      :to-be-truthy))
  (it-sequential
    "class canonical-key follows an alias chain back to the source class"
    (cl-cc/php::%php-register-runtime-class-tag "ClccCanonSrc")
    (let ((alias (format nil "ClccCanonAlias~A" (symbol-name (gensym)))))
      (expect (cl-cc/php::%php-class-alias "ClccCanonSrc" alias) :to-be-truthy)
      (expect
        (cl-cc/php::%php-runtime-class-canonical-key alias)
        :to-equal
        "CLCCCANONSRC")))
  (it-sequential
    "class-alias name forbids reserved array/callable aliases"
    (expect
      (cl-cc/php::%php-runtime-class-alias-name-forbidden-p "array")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-runtime-class-alias-name-forbidden-p "Callable")
      :to-be-truthy)
    (expect (cl-cc/php::%php-runtime-class-alias-name-forbidden-p "Foo") :to-be nil))
  (it-sequential
    "defined-class-symbol-p is false for an undefined class name"
    (expect
      (cl-cc/php::%php-defined-class-symbol-p "TotallyUndefinedXyzClass")
      :to-be
      nil))
  (it-sequential
    "class_exists sees runtime-tagged classes and rejects unknown ones"
    (expect (cl-cc/php::%php-class-exists "Closure") :to-be-truthy)
    (expect (cl-cc/php::%php-class-exists "NoSuchClassZzz") :to-be nil))
  (it-sequential
    "class_alias registers new aliases, rejects reserved names, and rejects unknown sources"
    (let ((alias (format nil "ClccAliasRuntime~A" (symbol-name (gensym)))))
      (expect (cl-cc/php::%php-class-alias "Closure" alias) :to-be-truthy)
      (expect (cl-cc/php::%php-class-exists alias) :to-be-truthy))
    (expect (cl-cc/php::%php-class-alias "NoSuchSrcZzz" "SomeAliasZzz") :to-be nil)
    (expect (cl-cc/php::%php-class-alias "Closure" "Locale") :to-be nil)
    (expect
      (handler-case (progn
          (cl-cc/php::%php-class-alias "Closure" "array")
          nil)
        (cl-cc/php:php-exception (e)
          e))
      :to-be-truthy))
  (it-sequential
    "interface_exists sees runtime-registered interfaces"
    (expect (cl-cc/php::%php-interface-exists "Dom\\ParentNode") :to-be-truthy)
    (expect (cl-cc/php::%php-interface-exists "NoIfaceZzz") :to-be nil))
  (it-sequential
    "function_exists resolves registered builtins and rejects unknown names"
    (expect (cl-cc/php::%php-function-exists "strlen") :to-be-truthy)
    (expect (cl-cc/php::%php-function-exists "no_such_func_zzz") :to-be nil))
  (it-sequential
    "method_exists resolves runtime class-name methods and object method tables"
    (expect
      (cl-cc/php::%php-method-exists "Locale" "addLikelySubtags")
      :to-be-truthy)
    (expect (cl-cc/php::%php-method-exists "Locale" "noSuchMethod") :to-be nil)
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Foo"
            (gethash "greet" obj) (lambda (&rest args)
          (declare (ignore args))
          "hi"))
      (expect (cl-cc/php::%php-method-exists obj "greet") :to-be-truthy)
      (expect (cl-cc/php::%php-method-exists obj "missing") :to-be nil)))
  (it-sequential
    "property_exists checks an object's visible property keys"
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Foo"
            (gethash "name" obj) "Bob")
      (expect (cl-cc/php::%php-property-exists obj "name") :to-be-truthy)
      (expect (cl-cc/php::%php-property-exists obj "age") :to-be nil)))
  (it-sequential
    "get_class returns an object's class name and nil for a bare string"
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "MyClass")
      (expect (cl-cc/php::%php-get-class obj) :to-equal "MyClass"))
    (expect (cl-cc/php::%php-get-class "plainstring") :to-be nil))
  (it-sequential
    "get_parent_class reads the __parent__ slot and yields nil when it is PHP null"
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Child"
            (gethash "__parent__" obj) "Parent")
      (expect (cl-cc/php::%php-get-parent-class obj) :to-equal "Parent"))
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Orphan"
            (gethash "__parent__" obj) cl-cc/php::+php-null+)
      (expect (cl-cc/php::%php-get-parent-class obj) :to-be nil)))
  (it-sequential
    "is_a and instanceof compare canonical class names for objects and strings"
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Foo")
      (expect (cl-cc/php::%php-is-a obj "Foo") :to-be-truthy)
      (expect (cl-cc/php::%php-is-a obj "Bar") :to-be nil)
      (expect (cl-cc/php::%php-instanceof obj "Foo") :to-be-truthy))
    (expect (cl-cc/php::%php-is-a "Foo" "foo") :to-be-truthy)
    (expect (cl-cc/php::%php-is-a 42 "Foo") :to-be nil))
  (it-sequential
    "get_object_vars returns visible properties and nil for non-objects"
    (let ((obj (make-hash-table :test #'equal)))
      (setf (gethash "__class__" obj) "Foo"
            (gethash "a" obj) 1
            (gethash "b" obj) 2)
      (let ((vars (cl-cc/php::%php-get-object-vars obj)))
        (expect (cl-cc/php::%php-array-ref vars "a") :to-be 1)
        (expect (cl-cc/php::%php-array-ref vars "b") :to-be 2)
        (expect (cl-cc/php::%php-count vars) :to-be 2)))
    (expect (cl-cc/php::%php-get-object-vars "notanobject") :to-be nil))
  (it-sequential
    "method-table-methods extracts string method names from a method-table array"
    (let ((methods (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set methods 0 "foo")
      (cl-cc/php::%php-array-set methods 1 "bar")
      (expect
        (cl-cc/php::%php-method-table-methods methods)
        :to-equal
        (list "foo" "bar"))))
  (it-sequential
    "get_class_methods lists a runtime class's registered methods"
    (let ((methods
          (cl-cc/php::%php-array-values-list (cl-cc/php::%php-get-class-methods "Locale"))))
      (expect (member "addLikelySubtags" methods :test #'string=) :to-be-truthy)))
  (it-sequential
    "reflection symbol helpers name, dedup, and array-ify class symbols"
    (expect
      (symbolp (cl-cc/php::%php-reflection-class-symbol-from-name "SomeName"))
      :to-be-truthy)
    (expect (cl-cc/php::%php-reflection-symbol-name "Foo") :to-equal "Foo")
    (expect (cl-cc/php::%php-reflection-symbol-name 'foo) :to-equal "FOO")
    (expect
      (cl-cc/php::%php-reflection-unique-symbols (list "a" "b" "a"))
      :to-equal
      (list "a" "b"))
    (let ((arr (cl-cc/php::%php-reflection-symbols-to-array (list "X" "Y"))))
      (expect (cl-cc/php::%php-array-ref arr "X") :to-equal "X")
      (expect (cl-cc/php::%php-array-ref arr "Y") :to-equal "Y")))
  (it-sequential
    "reflection descriptor predicate and symbol extraction key off __name__"
    (expect
      (cl-cc/php::%php-reflection-class-descriptor-p (make-hash-table))
      :to-be
      nil)
    (let ((descriptor (make-hash-table :test #'equal)))
      (setf (gethash :__name__ descriptor) 'myclass)
      (expect
        (cl-cc/php::%php-reflection-class-descriptor-p descriptor)
        :to-be-truthy)
      (expect (cl-cc/php::%php-reflection-class-symbol descriptor) :to-be 'myclass)))
  (it-sequential
    "reflection-interface-p and class-trait-symbols are empty for unknown names"
    (expect (cl-cc/php::%php-reflection-interface-p "NoSuchIfaceZzz") :to-be nil)
    (expect
      (cl-cc/php::%php-reflection-class-trait-symbols "NoClassZzz")
      :to-be
      nil)))
