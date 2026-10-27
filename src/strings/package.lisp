(defpackage #:cl-cc/php/strings
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:make-ast-call
                #:make-ast-quote
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/expressions
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-runtime-symbol
                #:php-consume
                #:php-tok-value
                #:php-var-sym
                #:register-php-expression-primary-parser
                #:tokenize-php-source
  )
  (:export
   #:%php-strlen
   #:%php-strtolower
   #:%php-strtoupper
  )
)
(in-package #:cl-cc/php/strings)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

