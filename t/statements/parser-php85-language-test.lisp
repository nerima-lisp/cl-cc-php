(in-package :cl-cc/php/statements/test)

(describe "PHP statement parser tests"
  (it-sequential
    "The PHP 8.5 (void) statement evaluates its operand and returns PHP null."
    (let* ((value (%php-first "<?php (void) 123;"))
           (forms (cl-cc/ast:ast-progn-forms value)))
      (expect (cl-cc/ast:ast-progn-p value) :to-be-truthy)
      (expect (= 2 (length forms)) :to-be-truthy)
      (expect (cl-cc/ast:ast-quote-value (second forms)) :to-be cl-cc/php:+php-null+))))
