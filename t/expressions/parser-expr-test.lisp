(in-package :cl-cc/php/expressions/test)

(describe "PHP expression parser tests"
  (it-sequential "php-parser-operator-helper-lowering modulo"
  (destructuring-bind (src expected-fn) (list "<?php $r = 7 % 4;" "%PHP-MODULO")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering bitwise-not"
  (destructuring-bind (src expected-fn) (list "<?php $r = ~1;" "%PHP-BITWISE-NOT")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering unary-plus"
  (destructuring-bind (src expected-fn) (list "<?php $r = +'7';" "%PHP-UNARY-PLUS")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering unary-minus"
  (destructuring-bind (src expected-fn) (list "<?php $r = -'7';" "%PHP-UNARY-MINUS")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering spaceship"
  (destructuring-bind (src expected-fn) (list "<?php $r = $a <=> $b;" "%PHP-SPACESHIP")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-operator-helper-lowering bitwise-and"
  (destructuring-bind (src expected-fn) (list "<?php $x = $a & $b;" "%PHP-BITWISE-AND")
    (let ((val (%php-first-binding-value src)))
    (expect (cl-cc/ast:ast-call-p val) :to-be-truthy)
    (expect (%php-call-name val) :to-equal expected-fn))))
  (it-sequential "php-parser-exponentiation-is-right-associative"
  (let ((value (%php-first-binding-value "<?php $result = 2 ** 3 ** 2;")))
    (expect (cl-cc/ast:ast-call-p value) :to-be-truthy)
    (expect (%php-call-name value) :to-equal "EXPT")
    (expect (cl-cc/ast:ast-call-p (second (cl-cc/ast:ast-call-args value))) :to-be-truthy)
    (expect (%php-call-name (second (cl-cc/ast:ast-call-args value))) :to-equal "EXPT")))
  (it-sequential "php-parser-shift-operators-lower-to-helpers"
  (let ((left (%php-first-binding-value "<?php $result = 1 << 3;"))
        (right (%php-first-binding-value "<?php $result = 8 >> 1;")))
    (expect (%php-call-name left) :to-equal "%PHP-SHIFT-LEFT")
    (expect (%php-call-name right) :to-equal "%PHP-SHIFT-RIGHT")))
  (it-sequential "php-parser-shift-precedence-is-below-addition"
  (let ((value (%php-first-binding-value "<?php $result = 1 + 2 << 3;")))
    (expect (%php-call-name value) :to-equal "%PHP-SHIFT-LEFT")
    (expect (%php-call-name (first (cl-cc/ast:ast-call-args value))) :to-equal "%PHP-ADD")))
  (it-sequential "php-parser-concat-precedence-is-below-addition"
  (let ((value (%php-first-binding-value "<?php $result = 1 + 2 . 3;")))
    (expect (%php-call-name value) :to-equal "%PHP-CONCAT")
    (expect (%php-call-name (first (cl-cc/ast:ast-call-args value))) :to-equal "%PHP-ADD")))
  (it-sequential "php-parser-bitwise-operators-lower-to-helpers"
  (let ((and-value (%php-first-binding-value "<?php $result = 6 & 3;"))
        (xor-value (%php-first-binding-value "<?php $result = 6 ^ 3;"))
        (or-value (%php-first-binding-value "<?php $result = 4 | 1;")))
    (expect (%php-call-name and-value) :to-equal "%PHP-BITWISE-AND")
    (expect (%php-call-name xor-value) :to-equal "%PHP-BITWISE-XOR")
    (expect (%php-call-name or-value) :to-equal "%PHP-BITWISE-OR")))
  (it-sequential "php-parser-bitwise-precedence-follows-php-order"
  (let ((value (%php-first-binding-value "<?php $result = 1 == 1 & 6 ^ 3 | 8;")))
    (expect (%php-call-name value) :to-equal "%PHP-BITWISE-OR")
    (let ((xor-node (first (cl-cc/ast:ast-call-args value))))
      (expect (%php-call-name xor-node) :to-equal "%PHP-BITWISE-XOR")
      (let ((and-node (first (cl-cc/ast:ast-call-args xor-node))))
        (expect (%php-call-name and-node) :to-equal "%PHP-BITWISE-AND")
        ;; == lowers to a %php-eq-loose call (PHP loose-equality type juggling),
        ;; and binds tighter than &, so it is the AND node's first operand.
        (let ((eq-node (first (cl-cc/ast:ast-call-args and-node))))
          (expect (cl-cc/ast:ast-call-p eq-node) :to-be-truthy)
          (expect (%php-call-name eq-node) :to-equal "%PHP-EQ-LOOSE"))))))
  (it-sequential "php-parser-pipe-operator-lowers-to-helper-call"
  (let ((ast (%php-first "<?php \"  HI  \" |> trim(...);")))
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func ast)) :to-be 'cl-cc/php:%php-pipe)
    (expect (= 2 (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)
    (expect (cl-cc/ast:ast-lambda-p (second (cl-cc/ast:ast-call-args ast))) :to-be-truthy))))
