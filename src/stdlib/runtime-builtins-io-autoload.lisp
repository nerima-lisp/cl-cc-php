;;;; runtime-builtins-io-autoload.lisp — PHP class relationship queries and the
;;;; SPL autoload registry.
;;;;
;;;; class_implements/class_parents/class_uses answer "what is this class
;;;; related to", and the spl_autoload_* trio records who would be asked to
;;;; load a class that is not there yet. The runtime does not model file
;;;; loading, but it keeps the registry PHP-visible so that
;;;; spl_autoload_functions and class_exists($c, true) behave.
;;;;
;;;; Compiled after runtime-builtins-io-objects.lisp on purpose: the class_*
;;;; functions are thin wrappers over the %php-reflection-* helpers defined
;;;; there. They used to sit in runtime-builtins-io.lisp, which is compiled
;;;; first, so every one of them was a forward reference.

(in-package :cl-cc/php)

(defun %php-class-implements (class &optional autoload)
  "PHP class_implements: return implemented interfaces keyed by interface name."
  (declare (ignore autoload))
  (%php-reflection-symbols-to-array
   (%php-reflection-class-interface-symbols class)))
(defun %php-class-parents (class &optional autoload)
  "PHP class_parents: return parent classes keyed by class name."
  (declare (ignore autoload))
  (%php-reflection-symbols-to-array
   (%php-reflection-class-parent-symbols class)))
(defun %php-class-uses (class &optional autoload)
  "PHP class_uses: return traits used directly by a class keyed by trait name."
  (declare (ignore autoload))
  (%php-reflection-symbols-to-array
   (%php-reflection-class-trait-symbols class)))

(defvar *php-spl-autoload-functions* nil
  "Registered PHP SPL autoload callbacks in call order.")

(defun %php-spl-autoload-callback-equal-p (left right)
  "Return true when two PHP callable values identify the same autoload entry."
  (or (eq left right)
      (equal left right)
      (and (stringp left) (stringp right) (string= left right))))

(defun %php-spl-autoload-callback-valid-p (callback)
  "Return true when CALLBACK is acceptable for spl_autoload_register."
  (or (stringp callback)
      (functionp callback)
      (cl-cc/vm::%vm-closure-object-p callback)
      (and (hash-table-p callback)
           (plusp (%php-count callback)))))

(defun %php-spl-autoload-register (&optional callback throw prepend)
  "PHP spl_autoload_register: add CALLBACK to the SPL autoload queue.

The runtime does not model file loading yet, but it now preserves PHP-visible
autoload state for spl_autoload_functions/unregister and class_exists($c, true)
plumbing."
  (let ((entry (if (or (null callback) (%php-null-p callback))
                   "spl_autoload"
                   callback)))
    (cond
      ((not (%php-spl-autoload-callback-valid-p entry))
       (if (%php-truthy throw)
           (%php-throw 'type-error
                       "spl_autoload_register(): Argument #1 ($callback) must be a valid callback")
           nil))
      ((some (lambda (registered)
               (%php-spl-autoload-callback-equal-p registered entry))
             *php-spl-autoload-functions*)
       t)
      ((%php-truthy prepend)
       (push entry *php-spl-autoload-functions*)
       t)
      (t
       (setf *php-spl-autoload-functions*
             (append *php-spl-autoload-functions* (list entry)))
       t))))

(defun %php-spl-autoload-unregister (&optional callback)
  "PHP spl_autoload_unregister: remove CALLBACK from the SPL autoload queue."
  (let* ((entry (if (or (null callback) (%php-null-p callback))
                    "spl_autoload"
                    callback))
         (before *php-spl-autoload-functions*))
    (setf *php-spl-autoload-functions*
          (remove-if (lambda (registered)
                       (%php-spl-autoload-callback-equal-p registered entry))
                     *php-spl-autoload-functions*))
    (not (= (length before) (length *php-spl-autoload-functions*)))))

(defun %php-spl-autoload-functions ()
  "PHP spl_autoload_functions: return registered autoload callbacks."
  (%php-list-to-array *php-spl-autoload-functions*))
