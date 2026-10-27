(defpackage #:cl-cc/php/types
  (:use #:cl)
  (:import-from #:cl-cc/php/syntax
                #:php-peek
                #:php-peek-type
                #:php-peek-value
                #:php-tok-value
                #:register-php-runtime-symbol
  )
  (:export
   #:register-php-array-empty-predicate
   #:%php-deref
   #:%php-make-ref
   #:%php-null-p
   #:%php-number-to-string
   #:%php-object-table-p
   #:%php-parse-integer-setting
   #:%php-parse-intersection-type
   #:%php-ref-p
   #:%php-ref-set!
   #:%php-stringify
   #:%php-truthy
   #:%php-type-atom-token-p
   #:%php-value-type
   #:+php-null+
   #:php-parse-type-annotation
   #:PHP-REF-P)
)
(in-package #:cl-cc/php/types)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

