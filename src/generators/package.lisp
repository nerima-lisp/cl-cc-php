(defpackage #:cl-cc/php/generators
  (:use #:cl)
  (:import-from #:cl-cc/php/arrays
                #:%php-array-pairs
                #:%php-array-values-list
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-call
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-cst-parse-unary-keyword-expression
                #:php-consume
                #:php-peek-type
                #:php-peek-value
                #:register-php-cst-keyword-expression-parser
                #:register-php-expression-keyword-parser
                #:register-php-runtime-symbol
  )
  (:import-from #:cl-cc/php/types
                #:+php-null+
  )
  (:export
   #:%php-foreach-pairs
   #:%php-foreach-values
   #:%php-generator-drain-values
   #:%php-generator-get-return
   #:%php-generator-next
   #:%php-generator-p
   #:%php-generator-valid
   #:%php-generator-value-count
   #:%php-make-generator
   #:%php-yield
   #:%php-yield-from
   #:*current-generator*
   #:PHP-GENERATOR-P)
)
(in-package #:cl-cc/php/generators)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

