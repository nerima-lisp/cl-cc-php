(defpackage #:cl-cc/php/arrays
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-call-args
                #:ast-list-elements
                #:ast-list-p
                #:ast-quote-p
                #:ast-quote-value
                #:ast-var-name
                #:ast-var-p
                #:make-ast-call
                #:make-ast-int
                #:make-ast-let
                #:make-ast-list
                #:make-ast-quote
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/errors
                #:%php-fatal-error
                #:%php-trigger-error
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-helper-var
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-cst-interior
                #:%php-helper-call-p
                #:%php-tok-to-cst
                #:php-consume
                #:php-cst-parse-expr
                #:php-expect
                #:php-peek
                #:php-peek-type
                #:php-peek-value
                #:php-ts-advance
                #:php-ts-at-type-p
                #:php-ts-peek-value
                #:register-php-array-expression-lowerer
                #:register-php-cst-keyword-expression-parser
                #:register-php-cst-primary-parser
                #:register-php-expression-keyword-parser
                #:register-php-expression-primary-parser
                #:register-php-runtime-symbol
  )
  (:import-from #:cl-cc/php/types
                #:register-php-array-empty-predicate
                #:%php-deref
                #:%php-make-ref
                #:%php-null-p
                #:%php-value-type
                #:+php-null+)
  (:export
   #:%php-array
   #:%php-array-call
   #:%php-array-empty-p
   #:%php-array-entry
   #:%php-array-key-exists
   #:%php-array-key-present-p
   #:%php-array-next-auto-index
   #:%php-array-ordered-keys
   #:%php-array-pairs
   #:%php-array-ref
   #:%php-array-ref-call-p
   #:%php-array-set
   #:%php-array-unset
   #:%php-array-unset-call
   #:%php-array-values-list
   #:%php-builtin-array-key-exists
   #:%php-count
   #:%php-double-arrow-p
   #:%php-foreach-by-ref
   #:%php-list-to-array
   #:%php-make-array
   #:%php-spread
   #:+php-array-next-index-key+
   #:+php-array-order-key+
   #:register-php-array-callable-resolver
  )
)
(in-package #:cl-cc/php/arrays)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

