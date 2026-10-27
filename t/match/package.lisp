(defpackage :cl-cc/php/match/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/ast
                #:ast-call-p #:ast-if-cond #:ast-if-p #:ast-let-bindings
                #:ast-let-body #:ast-let-p)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first #:%php-first-binding-value)
)

