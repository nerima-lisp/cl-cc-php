(in-package :cl-cc/php/expressions/test)

(describe "PHP expression parser tests"
  (it-sequential
    "The PHP 8.5 pipe operator lowers to the runtime pipe helper."
    (let ((ast (%php-first "<?php \"  HI  \" |> trim(...);")))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func ast))
        :to-be
        'cl-cc/php:%php-pipe)
      (expect (= 2 (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-lambda-p (second (cl-cc/ast:ast-call-args ast)))
        :to-be-truthy)))
  (it-sequential
    "The pipe helper applies a callable to the piped value."
    (expect (cl-cc/php:%php-pipe "HI" #'cl-cc/php:%php-strtolower) :to-equal "hi")))
