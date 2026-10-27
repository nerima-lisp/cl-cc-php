(defpackage :cl-cc/php/arrays/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-array #:%php-array-first #:%php-array-last #:%php-array-ref
                #:%php-array-unset #:%php-count #:+php-null+ #:parse-php-source
                #:php-check-supported-forms)
  (:import-from :cl-cc/php/arrays
                #:%php-array #:%php-array-ref #:%php-array-set #:%php-array-unset
                #:%php-count #:%php-make-array #:%php-array-ordered-keys #:%php-array-values-list
                #:%php-list-to-array)
  (:import-from :cl-cc/php/syntax
                #:php-check-supported-forms #:parse-php-source)
  (:import-from :cl-cc/php/types
                #:%php-null-p #:+php-null+)
  (:import-from :cl-cc/ast
                #:ast-call-p #:ast-let-bindings #:ast-let-p)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first #:%php-first-binding-value)
)

