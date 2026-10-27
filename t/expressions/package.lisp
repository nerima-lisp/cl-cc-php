(defpackage :cl-cc/php/expressions/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-bitwise-and #:%php-bitwise-not #:%php-bitwise-or #:%php-bitwise-xor
                #:%php-modulo #:%php-shift-left #:%php-shift-right #:%php-spaceship
                #:parse-php-source #:php-check-supported-forms #:tokenize-php-source)
  (:import-from :cl-cc/php/expressions
                #:%php-bitwise-and #:%php-bitwise-not #:%php-bitwise-or #:%php-bitwise-xor
                #:%php-modulo #:%php-pipe #:%php-shift-left #:%php-shift-right
                #:%php-spaceship)
  (:import-from :cl-cc/php/syntax
                #:make-php-token-stream #:php-check-supported-forms #:php-cst-parse-add #:php-cst-parse-arglist
                #:php-cst-parse-mul #:php-cst-parse-or #:php-cst-parse-postfix
                #:php-cst-parse-primary #:php-cst-parse-unary #:tokenize-php-source
                #:parse-php-source)
  (:import-from :cl-cc/ast
                #:ast-call-args #:ast-call-func #:ast-call-p #:ast-if-p
                #:ast-lambda-p #:ast-let-bindings #:ast-let-body #:ast-let-p
                #:ast-quote-p #:ast-quote-value #:ast-var-name)
  (:import-from :cl-cc/parse
                #:cst-interior-children #:cst-node-kind #:cst-token-value)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-cst-ts #:%php-first #:%php-first-binding-value)
)

