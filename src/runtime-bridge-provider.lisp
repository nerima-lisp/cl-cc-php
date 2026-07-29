;;;; runtime-bridge-provider.lisp — register PHP runtime helpers as a backend
;;;; bridge provider.
;;;;
;;;; The PHP frontend lowers builtins to calls on %PHP-* helpers, and the VM
;;;; host bridge is a whitelist: a symbol that is not registered is not callable
;;;; from compiled code, however well it is defined and exported. Without this
;;;; file every one of those helpers comes out as an undefined function at run
;;;; time -- measured at 217 errors when cl-cc was pointed at this repository.
;;;;
;;;; The pipeline used to scan :cl-cc/php for these itself, which meant the
;;;; orchestrator knew both this package's name and its naming convention. That
;;;; is the coupling §5-1 removes: PHP owns the knowledge and registers a
;;;; provider thunk, and the pipeline iterates
;;;; cl-cc/bootstrap:backend-bridge-providers without naming any backend.
;;;;
;;;; Mirrors cl-cc-javascript's file of the same name.
;;;;
;;;; Function bridges only. PHP's runtime does not hand compiled closures back
;;;; to the VM the way JavaScript's array methods do, so there is no
;;;; VM-integration installer to register alongside it.

(in-package :cl-cc/php)

(defun %php-host-bridge-entries ()
  "Return (symbol . function) pairs for every fbound, non-macro %PHP-* function
homed in :cl-cc/php.

Derived from the package rather than hand-listed: an explicit alist had already
drifted behind the lowering once, which is the failure this scan exists to
prevent."
  (let ((pkg (find-package :cl-cc/php))
        (entries '()))
    (when pkg
      (do-symbols (sym pkg)
        (when (and (eq (symbol-package sym) pkg)
                   (fboundp sym)
                   (not (macro-function sym))
                   (not (special-operator-p sym))
                   (let ((name (symbol-name sym)))
                     (and (>= (length name) 5)
                          (string= "%PHP-" name :end2 5))))
          (push (cons sym (fdefinition sym)) entries))))
    (nreverse entries)))

(register-backend-bridge-provider #'%php-host-bridge-entries)

(register-backend-parser
 :php (lambda (source) (values (parse-php-source source) nil)))
