;;;; runtime-builtins-register.lisp — the central PHP builtin registry.
;;;;
;;;; The machinery only: the two hash tables a PHP call is resolved through
;;;; (name -> function for dispatch, name -> symbol for parser lowering), the
;;;; register/lookup entry points, the VM host-bridge installation, and the
;;;; load-time driver that populates everything.
;;;;
;;;; The ~700 name-to-symbol entries themselves are data, not logic, and live
;;;; in runtime-builtins-register-names.lisp and
;;;; runtime-builtins-register-names-late.lisp. The split between those two is
;;;; not thematic: %php-register-all-builtins registers the first table,
;;;; seeds the by-reference parameter registry, then registers the second, and
;;;; that order is load-bearing.

(in-package :cl-cc/php)

(defun %php-register-vm-runtime-callables ()
  (let ((installer cl-cc/bootstrap:*vm-runtime-callable-installer*))
    (when installer
      (funcall installer "PHP-CURRENT-CLOSURE" #'%php-current-closure)))
  (cl-cc/vm:vm-register-host-bridge
   '%php-current-closure
   (lambda (&rest args)
     (apply (cl-cc/vm::%vm-runtime-callable "PHP-CURRENT-CLOSURE") args))))

(defun %php-register-host-bridges ()
  "Register PHP-specific host bridge aliases that bypass VM instruction names."
  (cl-cc/vm:vm-register-host-bridge 'max #'%php-max)
  (cl-cc/vm:vm-register-host-bridge 'min #'%php-min))

(defparameter *php-builtin-registry* (make-hash-table :test #'equal)
  "Map lowercase PHP builtin names to Common Lisp helper functions.")

(defparameter *php-builtin-symbol-registry* (make-hash-table :test #'equal)
  "Map lowercase PHP builtin names to helper symbols for parser lowering.")

(defun %php-normalize-builtin-name (name)
  "Normalize PHP builtin NAME for case-insensitive lookup."
  (string-downcase (string name)))

(defun %php-register-builtin (name function)
  "Register PHP builtin NAME to FUNCTION and return FUNCTION."
  ;; FUNCTION may be a function object or a function designator symbol. The
  ;; public registry stores the resolved helper function, while a side registry
  ;; keeps the symbol for parser integrations that lower calls to helper vars.
  ;; (%php-register-builtin "strlen" '%php-strlen) => #<FUNCTION %PHP-STRLEN>
  (let* ((key (%php-normalize-builtin-name name))
         (symbol (and (symbolp function) function))
         (fn (if symbol (symbol-function symbol) function)))
    (setf (gethash key *php-builtin-registry*) fn)
    (when symbol
      (setf (gethash key *php-builtin-symbol-registry*) symbol))
    fn))

(eval-when (:load-toplevel :execute)
  (%php-register-host-bridges))

(defun %php-lookup-builtin (name)
  "Return the helper function registered for PHP builtin NAME, or NIL."
  ;; (%php-lookup-builtin "STRLEN") => #<FUNCTION %PHP-STRLEN>
  (gethash (%php-normalize-builtin-name name) *php-builtin-registry*))

(defun %php-lookup-builtin-symbol (name)
  "Return the helper symbol registered for PHP builtin NAME, or NIL."
  (gethash (%php-normalize-builtin-name name) *php-builtin-symbol-registry*))

(defun %php-register-all-builtins ()
  "Register all supported PHP builtin helpers and return the registry."
  ;; The registry intentionally includes common aliases such as sizeof/count,
  ;; join/implode, and is_integer/is_int.
  ;; (%php-register-all-builtins) => *PHP-BUILTIN-REGISTRY*
  (clrhash *php-builtin-registry*)
  (clrhash *php-builtin-symbol-registry*)
  (dolist (entry +php-builtin-name-table+)
    (%php-register-builtin (car entry) (cdr entry)))
  (%php-seed-by-ref-param-registry *php-by-ref-param-registry*)
  (dolist (entry +php-builtin-name-table-2+)
    (%php-register-builtin (car entry) (cdr entry)))
  *php-builtin-registry*)

(eval-when (:load-toplevel :execute)
  (export '(*php-builtin-registry*
            %php-register-builtin
            %php-lookup-builtin
            %php-register-all-builtins
            %php-lookup-builtin-symbol
            %php-array-pairs)
          :cl-cc/php)
  (setf cl-cc/bootstrap:*runtime-vm-callable-register-hook*
        #'%php-register-vm-runtime-callables)
  (%php-register-vm-runtime-callables)
  (%php-register-all-builtins))
