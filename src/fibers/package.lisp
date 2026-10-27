(defpackage #:cl-cc/php/fibers
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-var-name
                #:ast-var-p
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-call
  )
  (:import-from #:cl-cc/php/functions
                #:%php-callable-function
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-runtime-symbol
                #:php-ident-sym
                #:register-php-expression-static-member-lowerer
                #:register-php-runtime-symbol
  )
  (:import-from #:cl-cc/php/types
                #:+php-null+
  )
  (:export
   #:%php-fiber-get-return
   #:%php-fiber-make
   #:%php-fiber-resume
   #:%php-fiber-running-p
   #:%php-fiber-start
   #:%php-fiber-started-p
   #:%php-fiber-suspend
   #:%php-fiber-suspended-p
   #:%php-fiber-terminated-p
  )
)
(in-package #:cl-cc/php/fibers)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

