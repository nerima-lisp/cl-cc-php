(defpackage #:cl-cc/php/match
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:make-ast-if
                #:make-ast-let
                #:make-ast-quote
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/arrays
                #:%php-double-arrow-p
  )
  (:import-from #:cl-cc/php/errors
                #:%php-fatal-error
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-call
                #:%php-eq-strict
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-consume-expected
                #:%php-cst-interior
                #:%php-tok-to-cst
                #:php-consume
                #:php-cst-parse-expr
                #:php-peek
                #:php-peek-type
                #:php-peek-value
                #:php-ts-advance
                #:php-ts-at-type-p
                #:php-ts-expect
                #:register-php-cst-keyword-expression-parser
                #:register-php-expression-keyword-parser
  )
  (:export #:%php-lower-match)
)
(in-package #:cl-cc/php/match)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

