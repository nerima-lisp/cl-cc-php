(in-package :cl-cc/php/strings/test)

(describe "PHP string tests"
  (it-sequential "php-runtime-concat-stringifies-values"
  (expect (cl-cc/php:%php-concat "Hello " 42) :to-equal "Hello 42")
  (expect (cl-cc/php:%php-concat "x" t) :to-equal "x1")
  (expect (cl-cc/php:%php-concat "x" cl-cc/php:+php-null+) :to-equal "x")))
