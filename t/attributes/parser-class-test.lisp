(in-package :cl-cc/php/attributes/test)

(defun %php-node-attributes (node)
  "Return PHP attribute metadata attached to NODE."
  (getf (cl-cc/ast:ast-imports node) :php-attributes))

(describe "PHP attribute tests"
  (it-sequential "php-parser-attribute-grouped-class-constants-signal-error"
  (let ((%%signaled1 nil)) (handler-case (progn (cl-cc/php:parse-php-source
     "<?php class C { #[Deprecated] public const A = 1, B = 2; }")) (error () (setf %%signaled1 t))) (expect %%signaled1 :to-be-truthy)))
  (it-sequential "php-parser-attribute-class-metadata"
  (let* ((ast (%php-first "<?php #[Attr] class Foo {}"))
         (attrs (%php-node-attributes ast)))
    (expect (cl-cc/ast:ast-defclass-p ast) :to-be-truthy)
    (expect (= 1 (length attrs)) :to-be-truthy)
    (expect (cl-cc/php:php-attribute-name (first attrs)) :to-equal "Attr")
    (expect (cl-cc/php:php-attribute-target-type (first attrs)) :to-be :class)))
  (it-sequential "php-parser-attribute-function-string-arg"
  (let* ((ast (%php-first "<?php #[Attr('value')] function foo() { return 1; }"))
         (attr (first (%php-node-attributes ast)))
         (arg (first (cl-cc/php:php-attribute-args attr))))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (cl-cc/php:php-attribute-name attr) :to-equal "Attr")
    (expect (cl-cc/ast:ast-quote-p arg) :to-be-truthy)
    (expect (cl-cc/ast:ast-quote-value arg) :to-equal "value")))
  (it-sequential "php-parser-multiple-attributes-class"
  (let* ((ast (%php-first "<?php #[Attr1, Attr2] class Bar {}"))
         (attrs (%php-node-attributes ast)))
    (expect (mapcar #'cl-cc/php:php-attribute-name attrs) :to-equal '("Attr1" "Attr2"))))
  (it-sequential "php-parser-attribute-named-arguments"
  (let* ((ast (%php-first "<?php #[Attr(42, name: 'val')] function bar() { return 1; }"))
         (attr (first (%php-node-attributes ast)))
         (args (cl-cc/php:php-attribute-args attr)))
    (expect (= 2 (length args)) :to-be-truthy)
    (expect (cl-cc/ast:ast-int-p (first args)) :to-be-truthy)
    (expect (getf (second args) :name) :to-equal "name")
    (expect (cl-cc/ast:ast-quote-p (getf (second args) :value)) :to-be-truthy)
    (expect (cl-cc/ast:ast-quote-value (getf (second args) :value)) :to-equal "val"))))
