(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential "php-parser-reference-syntax-is-supported foreach-ref-value"
  (destructuring-bind (src) (list "<?php foreach ($items as &$item) { echo $item; }")
    (let ((asts (cl-cc/php:parse-php-source src)))
    (expect (cl-cc/php:php-check-supported-forms asts) :to-be-truthy)))))
