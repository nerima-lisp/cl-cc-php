(defpackage #:cl-cc/php/errors
  (:use #:cl)
  (:import-from #:cl-cc/php/syntax
                #:%php-runtime-symbol
                #:register-php-runtime-symbol
  )
  (:export
   #:%php-current-error-handler
   #:%php-current-exception-handler
   #:%php-exception-class
   #:%php-exception-matches-p
   #:%php-exception-object-p
   #:%php-exception-value
   #:%php-fatal-error
   #:%php-make-exception
   #:%php-throw
   #:%php-trigger-error
   #:*php-error-handler-stack*
   #:*php-error-reporting-level*
   #:*php-exception-handler-stack*
   #:php-exception
   #:register-php-error-callable-resolver
  )
)
(in-package #:cl-cc/php/errors)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

