(defpackage :cl-cc/php/statements/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:+php-null+ #:parse-php-source #:parse-php-source-to-cst)
  (:import-from :cl-cc/php/syntax
                #:make-php-token #:php-parse-qualified-name #:parse-php-source
                #:parse-php-source-to-cst)
  (:import-from :cl-cc/php/types
                #:+php-null+)
  (:import-from :cl-cc/ast
                #:ast-block-body #:ast-block-p #:ast-call #:ast-call-args
                #:ast-call-func #:ast-call-p #:ast-defclass-name #:ast-defclass-superclasses
                #:ast-go-p #:ast-if-cond #:ast-if-else #:ast-if-p
                #:ast-if-then #:ast-imports #:ast-int #:ast-let
                #:ast-let-bindings #:ast-let-body #:ast-let-p #:ast-list-elements
                #:ast-list-p #:ast-make-instance-class #:ast-make-instance-p #:ast-namespace
                #:ast-progn #:ast-progn-forms #:ast-progn-p #:ast-quote
                #:ast-quote-p #:ast-quote-value #:ast-return-from #:ast-return-from-name
                #:ast-return-from-value #:ast-set-slot-value-p #:ast-set-slot-value-slot #:ast-set-slot-value-value
                #:ast-setq #:ast-setq-p #:ast-setq-value #:ast-setq-var
                #:ast-tagbody-p #:ast-tagbody-tags #:ast-throw-p #:ast-throw-tag
                #:ast-throw-value #:ast-unwind-protect-p #:ast-unwind-protected #:ast-var-name
                #:ast-var-p)
  (:import-from :cl-cc/parse
                #:cst-interior-children #:cst-interior-p #:cst-node-kind)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first #:%php-first-binding-value)
)

