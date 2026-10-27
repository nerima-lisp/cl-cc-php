;;;; runtime-builtins-array-e2e-test.lisp — direct tests of PHP array runtime helpers.

(in-package :cl-cc-php/test)

(describe
  "PHP array runtime helper tests"
  (it-sequential
    "php-runtime-array-unset-deletes-key"
    (let ((array (cl-cc/php:%php-array (list nil nil "a") (list nil nil "b"))))
      (expect (= 2 (cl-cc/php:%php-count array)) :to-be-truthy)
      (cl-cc/php:%php-array-unset array 0)
      (expect (= 1 (cl-cc/php:%php-count array)) :to-be-truthy)
      (expect (cl-cc/php:%php-array-ref array 0) :to-equal cl-cc/php:+php-null+)
      (expect (cl-cc/php:%php-array-ref array 1) :to-equal "b"))))
