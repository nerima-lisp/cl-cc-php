(in-package :cl-cc/php/generators/test)

(describe "PHP generator tests"
  (it-sequential "php-runtime-yield-helper-preserves-value"
  (expect (cl-cc/php:%php-yield 42) :to-equal '(:yield 42))
  (expect (cl-cc/php:%php-yield-from '(1 2)) :to-equal '(:yield-from (1 2)))))
