(in-package :cl-cc/php/strings/test)

(describe "PHP string tests"
  (it-sequential "php-parser-operator-helper-lowering str-interp"
  (destructuring-bind (src expected-fn) (list "<?php $s = \"Hello $name\";" "%PHP-CONCAT")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering braced-interp"
  (destructuring-bind (src expected-fn) (list "<?php $s = \"Hello {$name}\";" "%PHP-CONCAT")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn)))))
