(defpackage :cl-cc/php/classes/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-count #:%php-enum-case-list #:%php-enum-case-value #:%php-enum-cases
                #:%php-enum-from #:%php-enum-make-case #:%php-enum-try-from #:*php-interface-registry*
                #:*php-trait-registry* #:+php-null+ #:parse-php-source #:php-attribute-name
                #:php-check-supported-forms)
  (:import-from :cl-cc/php/arrays
                #:%php-count)
  (:import-from :cl-cc/php/attributes
                #:php-attribute-name)
  (:import-from :cl-cc/php/classes
                #:%php-clone-with #:%php-enum-case-list #:%php-enum-case-value #:%php-enum-cases
                #:%php-enum-from #:%php-enum-make-case #:%php-enum-try-from #:%php-lower-property-with-hooks
                #:php-cst-parse-new #:%php-mark-all-props-readonly #:%php-parse-asymmetric-visibility
                #:*php-interface-registry* #:*php-trait-applications* #:*php-trait-registry*)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms #:php-ident-sym #:parse-php-source)
  (:import-from :cl-cc/php/types
                #:+php-null+)
  (:import-from :cl-cc/ast
                #:ast-call-func #:ast-call-p #:ast-defclass #:ast-defclass-name
                #:ast-defclass-p #:ast-defclass-php-enum-cases #:ast-defclass-php-enum-type #:ast-defclass-php-kind
                #:ast-defclass-slots #:ast-defclass-superclasses #:ast-defun-name #:ast-defun-optional-params
                #:ast-defun-p #:ast-imports #:ast-int-p #:ast-int-value
                #:ast-let-bindings #:ast-let-body #:ast-let-p #:ast-make-instance-class
                #:ast-make-instance-p #:ast-progn-forms #:ast-progn-p #:ast-slot-allocation
                #:ast-slot-def-p #:ast-slot-initform #:ast-slot-name #:ast-slot-type
                #:ast-var-name #:make-ast-defclass #:make-ast-int #:make-ast-quote
                #:make-ast-return-from #:make-ast-slot-def)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-cst-ts #:%php-first #:%php-first-binding-value)
)

