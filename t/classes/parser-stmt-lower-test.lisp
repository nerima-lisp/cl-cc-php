(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  ;;; ─── :class handler → ast-defclass ───────────────────────────────────────

(it-sequential "php-parser-class-lowering"
  (expect (typep (%php-first "<?php class Dog { }") 'cl-cc/ast:ast-defclass) :to-be-truthy)
  (let ((ast (%php-first "<?php class Cat { }")))
    (expect (symbol-name (cl-cc/ast:ast-defclass-name ast)) :to-equal "CAT")))
(it-sequential "php-parser-class-with-extends"
  (let ((ast (%php-first "<?php class Puppy extends Dog { }")))
    (expect (some (lambda (s) (string= "DOG" (symbol-name s)))
                       (cl-cc/ast:ast-defclass-superclasses ast)) :to-be-truthy)))
(it-sequential "php-parser-class-with-implements"
  (let* ((ast (%php-first "<?php class Box implements IfaceA, IfaceB { }"))
         (names (mapcar #'symbol-name (cl-cc/ast:ast-defclass-superclasses ast))))
    (expect names :to-equal '("IFACEA" "IFACEB"))))
(it-sequential "php-parser-class-with-property"
  (let* ((ast   (%php-first "<?php class Point { public $x; public $y; }"))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (= 2 (length slots)) :to-be-truthy)
    (expect (every #'cl-cc/ast:ast-slot-def-p slots) :to-be-truthy)))
(it-sequential "php-parser-bare-defclass-is-rejected"
  (let ((%%signaled1 nil)) (handler-case (progn (cl-cc/php:php-check-supported-forms
     (list (cl-cc/ast:make-ast-defclass)))) (error () (setf %%signaled1 t))) (expect %%signaled1 :to-be-truthy))))
