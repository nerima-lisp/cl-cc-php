(defpackage :cl-cc/php/types/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-array #:+php-null+ #:parse-php-source #:php-check-supported-forms)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms #:parse-php-source)
  (:import-from :cl-cc/php/types
                #:%php-parse-intersection-type #:+php-null+)
  (:import-from :cl-cc/ast
                #:ast-call-args #:ast-call-p #:ast-children #:ast-defclass-slots
                #:ast-defun-declarations #:ast-defun-p #:ast-if-cond #:ast-if-p
                #:ast-int-p #:ast-int-value #:ast-let-bindings #:ast-let-body
                #:ast-let-p #:ast-node #:ast-progn-forms #:ast-progn-p
                #:ast-quote-p #:ast-quote-value #:ast-setq-p #:ast-setq-value
                #:ast-setq-var #:ast-slot-type #:ast-var-p)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first #:%php-first-binding-value)
)

