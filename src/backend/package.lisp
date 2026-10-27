(defpackage #:cl-cc/php/backend
  (:use #:cl)
  (:import-from #:cl-cc/bootstrap
                #:register-backend-bridge-provider
                #:register-backend-input-validator
                #:register-backend-parser)
  (:import-from #:cl-cc/php/syntax
                #:parse-php-source
                #:php-check-supported-forms
                #:php-runtime-packages)
  (:export
   #:%php-host-bridge-entries))
(in-package #:cl-cc/php/backend)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

