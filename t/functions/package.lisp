(defpackage :cl-cc/php/functions/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:parse-php-source #:php-check-supported-forms)
  (:import-from :cl-cc/php/functions
                #:%php-callable-ref #:%php-first-class-callable-p #:%php-named-args-to-positional)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms #:%php-named-arg-p #:parse-php-source)
  (:import-from :cl-cc/ast
                #:ast-apply-p #:ast-call-args #:ast-call-func #:ast-call-p
                #:ast-defun #:ast-defun-declarations #:ast-defun-name #:ast-defun-p
                #:ast-defun-params #:ast-int-p #:ast-lambda-body #:ast-lambda-declarations
                #:ast-lambda-p #:ast-lambda-params #:ast-let-body #:ast-let-p
                #:ast-quote-p #:ast-var-name #:ast-var-p #:make-ast-int
                #:make-ast-quote #:make-ast-var)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first #:%php-first-binding-value)
)

