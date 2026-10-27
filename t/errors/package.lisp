(defpackage :cl-cc/php/errors/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-exception-matches-p #:%php-exception-object-p #:%php-exception-value #:%php-make-exception
                #:php-exception)
  (:import-from :cl-cc/php/errors
                #:%php-exception-class #:%php-exception-matches-p #:%php-exception-object-p #:%php-exception-value
                #:%php-make-exception #:%php-throw #:php-exception)
  (:import-from :cl-cc/ast
                #:ast-let-p #:ast-unwind-protect-p #:ast-unwind-protected)
  (:import-from :cl-cc/php/syntax/test
                #:%php-first)
)

