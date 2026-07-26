;;;; runtime-builtins-io-ini.lisp — PHP INI settings, error reporting, and the
;;;; error/exception handler stacks.
;;;;
;;;; One concern: the mutable diagnostic configuration of a running PHP script.
;;;; ini_get/ini_set is the store, error_reporting is one particular setting
;;;; with its own accessor, set_error_handler/set_exception_handler are stacks
;;;; layered on top of it, and trigger_error is the one function that reads all
;;;; three to decide whether a message is reported and to whom.
;;;;
;;;; The defaults this reads (*php-ini-defaults*) live in
;;;; runtime-builtins-io-data.lisp.

(in-package :cl-cc/php)

(defvar *php-ini-settings* nil
  "Mutable PHP INI settings for the current Lisp image.")

(defvar *php-error-reporting-level* 32767
  "Current PHP error_reporting() level.")

(defvar *php-error-handler-stack* nil
  "Stack of active PHP error handlers as (CALLBACK . ERROR-MASK).")

(defvar *php-exception-handler-stack* nil
  "Stack of active PHP exception handlers.")

(defun %php-current-error-handler ()
  "Return the active PHP error handler entry, or NIL."
  (first *php-error-handler-stack*))

(defun %php-current-exception-handler ()
  "Return the active PHP exception handler, or NIL."
  (first *php-exception-handler-stack*))

(defun %php-get-error-handler ()
  "PHP get_error_handler: return the active custom error handler, or null."
  (let ((entry (%php-current-error-handler)))
    (if entry
        (car entry)
        +php-null+)))

(defun %php-get-exception-handler ()
  "PHP get_exception_handler: return the active custom exception handler, or null."
  (or (%php-current-exception-handler) +php-null+))

(defun %php-valid-callback-or-throw (callback function-name)
  "Return CALLBACK when it is callable, otherwise signal a PHP TypeError."
  (if (%php-callable-function callback)
      callback
      (%php-throw 'type-error
                  (format nil "~A(): Argument #1 ($callback) must be a valid callback"
                          function-name))))

(defun %php-ensure-ini-settings ()
  (or *php-ini-settings*
      (setf *php-ini-settings*
            (let ((table (make-hash-table :test 'equal)))
              (dolist (entry *php-ini-defaults* table)
                (setf (gethash (car entry) table) (cdr entry)))))))

(defun %php-ini-key (varname)
  (string-downcase (%php-stringify varname)))

(defun %php-parse-integer-setting (value fallback)
  (handler-case
      (parse-integer (%php-stringify value) :junk-allowed t)
    (error () fallback)))

(defun %php-ini-get (varname)
  "PHP ini_get: get an INI configuration value."
  (let* ((key (%php-ini-key varname))
         (table (%php-ensure-ini-settings)))
    (if (string= key "date.timezone")
        (%php-date-default-timezone-get)
        (multiple-value-bind (value present-p) (gethash key table)
          (if present-p value nil)))))

(defun %php-ini-set (varname newvalue)
  "PHP ini_set: set an INI configuration value and return the previous value."
  (let* ((key (%php-ini-key varname))
         (table (%php-ensure-ini-settings))
         (old (%php-ini-get key)))
    (cond
      ((string= key "max_memory_limit")
       nil)
      ((string= key "date.timezone")
       (when (%php-date-default-timezone-set newvalue)
         (setf (gethash key table) (%php-date-default-timezone-get))
         old))
      ((string= key "memory_limit")
       (let ((max-memory-limit (%php-ini-get "max_memory_limit")))
         (when (and max-memory-limit
                    (%php-memory-limit-exceeds-p newvalue max-memory-limit))
           (format *error-output*
                   "memory_limit exceeds max_memory_limit (~A); clamping to ~A~%"
                   max-memory-limit
                   max-memory-limit)
           (setf newvalue max-memory-limit))
         (setf (gethash key table) (%php-stringify newvalue))
         old))
      (t
       (setf (gethash key table) (%php-stringify newvalue))
       (when (string= key "error_reporting")
         (setf *php-error-reporting-level*
               (%php-parse-integer-setting newvalue *php-error-reporting-level*)))
       old))))

(defun %php-set-error-handler (callback &optional error-types)
  "PHP set_error_handler: install CALLBACK and return the previous handler."
  (let* ((old (car (%php-current-error-handler)))
         (mask (%php-parse-integer-setting
                (if (and error-types (not (%php-null-p error-types)))
                    error-types
                    *php-error-reporting-level*)
                *php-error-reporting-level*))
         (cb (%php-valid-callback-or-throw callback "set_error_handler")))
    (push (cons cb mask) *php-error-handler-stack*)
    old))

(defun %php-restore-error-handler ()
  "PHP restore_error_handler: restore the previous custom error handler."
  (when *php-error-handler-stack*
    (pop *php-error-handler-stack*))
  t)

(defun %php-set-exception-handler (callback)
  "PHP set_exception_handler: install CALLBACK and return the previous handler."
  (let ((old (%php-current-exception-handler))
        (cb (%php-valid-callback-or-throw callback "set_exception_handler")))
    (push cb *php-exception-handler-stack*)
    old))

(defun %php-restore-exception-handler ()
  "PHP restore_exception_handler: restore the previous custom exception handler."
  (when *php-exception-handler-stack*
    (pop *php-exception-handler-stack*))
  t)

(defun %php-error-reporting (&optional level)
  "PHP error_reporting: set/get error reporting level."
  (let ((old *php-error-reporting-level*))
    (when level
      (setf *php-error-reporting-level*
            (%php-parse-integer-setting level *php-error-reporting-level*))
      (setf (gethash "error_reporting" (%php-ensure-ini-settings))
            (%php-stringify *php-error-reporting-level*)))
    old))

(defun %php-trigger-error (message &optional (error-type 256))
  "PHP trigger_error: generate a user-level error."
  (let* ((errno (%php-parse-integer-setting error-type 256))
         (handler-entry (%php-current-error-handler))
         (reportable-p (logtest errno *php-error-reporting-level*))
         (handled-p nil))
    (when (and reportable-p handler-entry (logtest errno (cdr handler-entry)))
      (let ((fn (%php-callable-function (car handler-entry))))
        (when fn
          (setf handled-p
                (%php-truthy
                 (funcall fn errno (%php-stringify message) nil nil))))))
    (unless (or handled-p (not reportable-p))
      ;; User-triggered errors (E_USER_*) report to stdout so trigger_error() is
      ;; observable in program output; engine-generated diagnostics (E_DEPRECATED,
      ;; E_WARNING, …) go to stderr as PHP's CLI SAPI does, keeping them out of
      ;; captured program output (e.g. serialize() using __sleep()).
      (if (logtest errno (logior 256 512 1024 16384)) ; E_USER_ERROR/WARNING/NOTICE/DEPRECATED
          (format t "~A~%" (%php-stringify message))
          (format *error-output* "~A~%" (%php-stringify message)))))
  t)
