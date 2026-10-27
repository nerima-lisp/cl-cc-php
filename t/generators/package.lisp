(defpackage :cl-cc/php/generators/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-yield #:%php-yield-from #:php-check-supported-forms)
  (:import-from :cl-cc/php/generators
                #:%php-generator-drain-values #:%php-generator-get-return #:%php-generator-p #:%php-make-generator
                #:%php-yield #:%php-yield-from)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms)
  (:import-from :cl-cc/ast
                #:ast-block-body #:ast-block-p #:ast-call-args #:ast-call-p
                #:ast-defun-body #:ast-let-bindings #:ast-let-body #:ast-let-p)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first)
)

