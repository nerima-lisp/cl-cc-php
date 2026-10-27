(in-package :cl-cc/php/types/test)

(describe "PHP type and reference tests"
  (it-sequential "php-parser-function-type-annotation-preservation"
  (let ((ast (%php-first "<?php function add(int $a, ?string $b = null, int|string $c): bool { return true; }")))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (let ((decls (cl-cc/ast:ast-defun-declarations ast)))
      (expect (getf decls :php-return-type) :to-equal "bool")
      (expect (mapcar (lambda (entry)
                              (cons (symbol-name (car entry)) (cdr entry)))
                            (getf decls :php-param-types)) :to-equal '(("a" . "int") ("b" . "?string") ("c" . "int|string"))))))
  (it-sequential "php-parser-function-special-return-types"
  (dolist (case '(("void" . "void")
                  ("never" . "never")
                  ("mixed" . "mixed")
                  ("static" . "static")
                  ("?int" . "?int")
                  ("int|string|null" . "int|string|null")
                  ("Countable&Iterator" . "countable&iterator")
                  ("(Countable&Iterator)|Traversable" . "(countable&iterator)|traversable")
                  ("Countable|(Iterator&Traversable)" . "countable|(iterator&traversable)")))
    (let* ((source (format nil "<?php function f(): ~A { return 1; }" (car case)))
           (ast (%php-first source)))
      (expect (getf (cl-cc/ast:ast-defun-declarations ast) :php-return-type) :to-equal (cdr case)))))
  (it-sequential "php-parser-dnf-type-annotation-preservation"
  (let* ((fn (%php-first "<?php function f((A&B)|C $x): D|(E&F) { return $x; }"))
         (class (%php-first "<?php class Box { public (A&B)|C $value; const D|(E&F) KIND = 1; }"))
         (decls (cl-cc/ast:ast-defun-declarations fn))
         (slots (cl-cc/ast:ast-defclass-slots class)))
    (expect (mapcar (lambda (entry)
                            (cons (symbol-name (car entry)) (cdr entry)))
                          (getf decls :php-param-types)) :to-equal '(("x" . "(a&b)|c")))
    (expect (getf decls :php-return-type) :to-equal "d|(e&f)")
    (expect (mapcar #'cl-cc/ast:ast-slot-type slots) :to-equal '("(a&b)|c" "d|(e&f)"))))
  (it-sequential "php-parser-reference-parameter-and-foreach-are-supported"
  (dolist (src '("<?php function f(&$x) { return $x; }"
                 "<?php foreach ($items as &$item) { echo $item; }"))
    (let ((asts (cl-cc/php:parse-php-source src)))
      (expect (cl-cc/php:php-check-supported-forms asts) :to-be-truthy)))))
