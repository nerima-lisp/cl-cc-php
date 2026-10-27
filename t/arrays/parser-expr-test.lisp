(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential "php-parser-operator-helper-lowering array-ref"
  (destructuring-bind (src expected-fn) (list "<?php $x = $a[0];" "%PHP-ARRAY-REF")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn)))))
