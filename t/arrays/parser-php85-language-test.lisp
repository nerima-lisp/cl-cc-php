(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential
    "array_first() and array_last() return inserted first/last values."
    (let ((array (cl-cc/php:%php-array)))
      (cl-cc/php:%php-array-set array "a" 10)
      (cl-cc/php:%php-array-set array "b" 20)
      (expect (= 10 (cl-cc/php:%php-array-first array)) :to-be-truthy)
      (expect (= 20 (cl-cc/php:%php-array-last array)) :to-be-truthy)))
  (it-sequential
    "array_first() and array_last() return null for empty arrays."
    (let ((array (cl-cc/php:%php-array)))
      (expect (cl-cc/php:%php-array-first array) :to-be cl-cc/php:+php-null+)
      (expect (cl-cc/php:%php-array-last array) :to-be cl-cc/php:+php-null+))))
