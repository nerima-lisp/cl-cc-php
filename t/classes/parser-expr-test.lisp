(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  (it-sequential "php-parser-clone-function-accepts-single-argument"
  (let* ((value (%php-first-binding-value "<?php $b = clone($a);"))
         (clone-call (cdr (first (cl-cc/ast:ast-let-bindings value)))))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (%php-call-name clone-call) :to-equal "%PHP-CLONE")))
  (it-sequential "php-parser-clone-with-lowers-to-helper-call"
  (let* ((value (%php-first-binding-value "<?php $b = clone($a, ['x' => 9]);"))
         (body (cl-cc/ast:ast-let-body value))
         (with-call (second body)))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (cl-cc/ast:ast-call-p with-call) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func with-call)) :to-be 'cl-cc/php:%php-clone-with)))
  (it-sequential "php-parser-qualified-clone-function-accepts-single-argument"
  (let* ((value (%php-first-binding-value "<?php $b = \\clone($a);"))
         (clone-call (cdr (first (cl-cc/ast:ast-let-bindings value)))))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (%php-call-name clone-call) :to-equal "%PHP-CLONE")))
  (it-sequential "php-parser-qualified-clone-with-lowers-to-helper-call"
  (let* ((value (%php-first-binding-value "<?php $b = \\clone($a, ['x' => 9]);"))
         (body (cl-cc/ast:ast-let-body value))
         (with-call (second body)))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (cl-cc/ast:ast-call-p with-call) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func with-call)) :to-be 'cl-cc/php:%php-clone-with))))
