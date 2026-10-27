(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  (it-sequential
    "PHP 8.5 clone-with syntax lowers to the clone-with runtime helper."
    (let* ((value (%php-first-binding-value "<?php $b = clone($a, ['x' => 9]);"))
           (body (cl-cc/ast:ast-let-body value))
           (with-call (second body)))
      (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
      (expect (cl-cc/ast:ast-call-p with-call) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func with-call))
        :to-be
        'cl-cc/php:%php-clone-with))))
