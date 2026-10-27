(defpackage :cl-cc/php/backend/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:php-check-supported-forms)
  (:import-from :cl-cc/php/backend
                #:%php-host-bridge-entries)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms #:php-runtime-packages)
  (:import-from :cl-cc/ast
                #:ast-call-p)
)

