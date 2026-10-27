(in-package :cl-cc/php/stdlib/test)

(describe "PHP type and reference tests"
  (it-sequential
    "The %php-empty helper mirrors PHP truthiness for empty values."
    (expect (cl-cc/php/stdlib::%php-empty nil) :to-be-truthy)
    (expect (cl-cc/php/stdlib::%php-empty 0) :to-be-truthy)
    (expect (cl-cc/php/stdlib::%php-empty "0") :to-be-truthy)
    (expect (cl-cc/php/stdlib::%php-empty "hello") :to-be-falsy)
    (let ((array (cl-cc/php:%php-array)))
      (expect (cl-cc/php/stdlib::%php-empty array) :to-be-truthy)))
  (it-sequential
    "The %php-is-null helper distinguishes PHP null from other values."
    (expect (cl-cc/php/stdlib::%php-is-null cl-cc/php:+php-null+) :to-be-truthy)
    (expect (cl-cc/php/stdlib::%php-is-null 0) :to-be-falsy)
    (expect (cl-cc/php/stdlib::%php-is-null "") :to-be-falsy))
  (it-sequential
    "The %php-unset helper always returns PHP null."
    (expect (cl-cc/php/stdlib::%php-unset "ignored") :to-be cl-cc/php:+php-null+)))
