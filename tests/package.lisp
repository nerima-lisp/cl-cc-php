;;;; tests/package.lisp

(defpackage :cl-cc-php/test
  (:use :cl :cl-cc/ast :cl-cc/parse :cl-cc/php)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect
                #:it-sequential
                #:it-sequential-each
                #:it-property
                #:signals
                #:run-all
                #:gen-string)
  (:export #:run-tests))

(in-package :cl-cc-php/test)

(defun run-tests ()
  "Run the full cl-cc-php test suite, signalling an error unless every test
passes. RUN-ALL already reports failures to *standard-output* via the :spec
reporter; this just turns \"not all green\" into a nonzero-exit condition for
CI/script callers."
  (unless (run-all :reporter :spec)
    (error "cl-cc-php test suite failed"))
  (format t "~&cl-cc-php/test: successful completion with 0 failures~%")
  t)
