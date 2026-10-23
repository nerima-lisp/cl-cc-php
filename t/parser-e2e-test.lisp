;;;; parser-e2e-test.lisp — parser and runtime operator-helper tests.

(in-package :cl-cc-php/test)

(describe
  "PHP parser and runtime helper tests: core language"
  (it-sequential
    "php-runtime-expression-operator-helpers"
    (expect (= 3 (cl-cc/php:%php-modulo 7 4)) :to-be-truthy)
    (expect (= -1 (cl-cc/php:%php-modulo -7 3)) :to-be-truthy)
    (expect (= 8 (cl-cc/php:%php-shift-left 1 3)) :to-be-truthy)
    (expect (= -4 (cl-cc/php:%php-shift-right -8 1)) :to-be-truthy)
    (expect (= -1 (cl-cc/php:%php-spaceship 1 2)) :to-be-truthy)
    (expect (= 0 (cl-cc/php:%php-spaceship "2" 2)) :to-be-truthy)
    (expect (= 2 (cl-cc/php:%php-bitwise-and 6 3)) :to-be-truthy)
    (expect (= 7 (cl-cc/php:%php-bitwise-or 6 3)) :to-be-truthy)
    (expect (= 5 (cl-cc/php:%php-bitwise-xor 6 3)) :to-be-truthy)
    (expect (= -2 (cl-cc/php:%php-bitwise-not 1)) :to-be-truthy))
  (it-sequential
    "php-parse-expression-operators"
    (expect
      (= 10
         (length
          (cl-cc/php:parse-php-source
           "<?php $a = 2 ** 3 ** 2; $b = 7 % 4; $c = 1 << 3; $d = 8 >> 1; $e = 1 <=> 2; $f = 6 & 3; $g = 6 ^ 3; $h = 4 | 1; $i = ~1; $j = 1 + 2 . 3;")))
      :to-be-truthy)))
