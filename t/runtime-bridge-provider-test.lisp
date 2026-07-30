;;;; runtime-bridge-provider-test.lisp — src/runtime-bridge-provider.lisp — the %PHP-* backend
;;;; bridge scan.
;;;;
;;;; %php-host-bridge-entries is called by the pipeline orchestrator, not by anything in this
;;;; package's own PHP-lowering code, so no e2e test calls it directly — the e2e suites only
;;;; observe that its result was usable. This tests the scan itself: every entry it returns
;;;; must be a real, callable %PHP-* function, and a handful of builtins known to be defined in
;;;; this package must be among them.

(in-package :cl-cc-php/test)

(describe "PHP backend bridge provider"

(it-sequential "%php-host-bridge-entries returns only fbound, non-macro %PHP-* symbols from cl-cc/php"
  (let ((entries (cl-cc/php::%php-host-bridge-entries)))
    (expect (> (length entries) 0) :to-be-truthy)
    (dolist (entry entries)
      (let ((sym (car entry))
            (fn (cdr entry)))
        (expect (eq (symbol-package sym) (find-package :cl-cc/php)) :to-be-truthy)
        (expect (string= "%PHP-" (symbol-name sym) :end2 5) :to-be-truthy)
        (expect (fboundp sym) :to-be-truthy)
        (expect (not (macro-function sym)) :to-be-truthy)
        (expect (functionp fn) :to-be-truthy)
        (expect (eq fn (fdefinition sym)) :to-be-truthy)))))

(it-sequential "%php-host-bridge-entries includes known runtime builtins"
  (let ((names
          (mapcar (lambda (entry) (symbol-name (car entry)))
                  (cl-cc/php::%php-host-bridge-entries))))
    (dolist (expected '("%PHP-ABS" "%PHP-ARRAY-MERGE" "%PHP-STRLEN"))
      (expect (member expected names :test #'string=) :to-be-truthy))))

  )
