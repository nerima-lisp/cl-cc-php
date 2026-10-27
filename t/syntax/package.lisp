(defpackage :cl-cc/php/syntax/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:parse-php-source #:tokenize-php-source)
  (:import-from :cl-cc/php/syntax
                #:make-php-token-stream #:php-tok-type #:php-tok-value #:php-ts-advance
                #:php-ts-at-end-p #:php-ts-peek-type #:php-ts-peek-value #:php-ts-skip-semis
                #:tokenize-php-source #:parse-php-source)
  (:import-from :cl-cc/ast
                #:ast-binop-p #:ast-call-args #:ast-call-p #:ast-defclass-name #:ast-defclass-p
                #:ast-defun-name #:ast-defun-p #:ast-if-p #:ast-int-p #:ast-int-value
                #:ast-let-bindings #:ast-let-body #:ast-let-p
                #:ast-quote-p #:ast-quote-value #:ast-setq-p #:ast-var-name #:ast-var-p)
  
  (:export #:%php-first #:%php-first-binding-value #:%php-call-name #:%php-cst-ts))

