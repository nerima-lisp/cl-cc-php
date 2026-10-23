;;;; runtime-bridge-provider-test.lisp — src/runtime-bridge-provider.lisp — the %PHP-* backend
;;;; bridge scan.
;;;;
;;;; %php-host-bridge-entries is called by the compiler pipeline, not by this package's own PHP
;;;; frontend. Compiler-driven cases observe it indirectly and are reserved for umbrella-level
;;;; integration. This test checks the scan directly: every returned entry must be a real,
;;;; callable %PHP-* function, including several known builtins.

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
