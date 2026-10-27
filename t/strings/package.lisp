(defpackage :cl-cc/php/strings/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-concat #:+php-null+)
  (:import-from :cl-cc/php/strings
                #:%php-strtolower #:%php-strtoupper)
  (:import-from :cl-cc/ast
                #:ast-call-p)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first-binding-value)
  (:import-from :cl-cc/php/expressions
                #:%php-concat)
)

