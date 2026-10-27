(defpackage :cl-cc/php/attributes/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:parse-php-source #:php-attribute-args #:php-attribute-name #:php-attribute-target-type)
  (:import-from :cl-cc/php/attributes
                #:php-attribute-args #:php-attribute-name #:php-attribute-target-type)
  (:import-from :cl-cc/ast
                #:ast-defclass-p #:ast-defclass-slots #:ast-defun-p #:ast-defvar-name
                #:ast-defvar-p #:ast-imports #:ast-int-p #:ast-progn-forms
                #:ast-progn-p #:ast-quote-p #:ast-quote-value #:ast-slot-def-p
                #:ast-slot-initform #:make-ast-slot-def)
  (:import-from :cl-cc/php/syntax/test
                #:%php-first)
  (:import-from :cl-cc/php/syntax
                #:parse-php-source)
)

