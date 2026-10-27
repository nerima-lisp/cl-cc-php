(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential
    "The %php-compact helper forwards its arguments into an array."
    (let ((array (cl-cc/php:%php-compact "x" "y")))
      (expect (hash-table-p array) :to-be-truthy)
      (expect (= 2 (hash-table-count array)) :to-be-truthy)))
  (it-sequential
    "The %php-extract helper returns zero for the fallback path."
    (expect (= 0 (cl-cc/php:%php-extract (cl-cc/php:%php-array))) :to-be-truthy)))
