(in-package #:cl-cc/php/errors)

(define-condition php-exception (error)
  ((class-name :initarg :class-name :reader php-exception-class-name)
   (value :initarg :value :reader php-exception-value))
  (:report (lambda (condition stream)
             (format stream "PHP exception~@[ of class ~A~]: ~S"
                     (php-exception-class-name condition)
                     (php-exception-value condition)))))

(defun %php-fatal-error (message)
  "Emit a PHP fatal error message and optionally include a VM backtrace."
  (format *error-output* "~&~A~%" message)
  (let ((state cl-cc/vm:*vm-state*))
    (when (and (funcall (%PARSER-PHP-RUNTIME-SYMBOL :truthy) (funcall (%PARSER-PHP-RUNTIME-SYMBOL :ini-get) "fatal_error_backtraces"))
               state)
      (cl-cc/vm:vm-print-backtrace state))
    (error 'cl-cc/vm:vm-fatal-error
           :message message
           :print-backtrace-p nil)))

(defun %php-exception-matches-p (condition class-name)
  "Return true when PHP exception CONDITION matches CLASS-NAME."
  (and (%php-exception-object-p condition)
       (cond ((listp class-name)
              (some (lambda (name) (%php-exception-matches-p condition name)) class-name))
             (t
              (let ((actual (%php-exception-class condition)))
                (or (null class-name)
                    (eq class-name 'php-exception)
                    (eq class-name actual)
                    (and actual
                         (string= (symbol-name class-name) (symbol-name actual)))))))))

(defun %php-exception-value (value)
  "Return the thrown PHP exception value from VALUE, preserving non-payloads."
  (cond ((typep value 'php-exception) (php-exception-value value))
        ((and (consp value) (eq (first value) :php-exception)) (third value))
        (t value)))

(defun %php-exception-class (value)
  "Return VALUE's PHP exception class metadata when present."
  (cond ((typep value 'php-exception) (php-exception-class-name value))
        ((and (consp value) (eq (first value) :php-exception)) (second value))
        (t nil)))

(defun %php-exception-object-p (value)
  "Return true when VALUE is a PHP exception payload or condition."
  (or (typep value 'php-exception)
      (and (consp value) (eq (first value) :php-exception))))

(defun %php-make-exception (class-name value)
  "Return a lightweight PHP exception payload for VM catch/throw lowering."
  (list :php-exception class-name value))

(defun %php-throw (class-name value)
  "Signal VALUE as a PHP exception with CLASS-NAME metadata."
  (error 'php-exception :class-name class-name :value value))
(in-package #:cl-cc/php/errors)

(in-package #:cl-cc/php/errors)

(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :make-exception '%php-make-exception))

(in-package #:cl-cc/php/errors)

(defvar *php-error-callable-resolver* nil)

(defun register-php-error-callable-resolver (resolver)
  (check-type resolver function)
  (when *php-error-callable-resolver*
    (error "PHP error callable resolver is already registered."))
  (setf *php-error-callable-resolver* resolver))

(defvar *php-exception-handler-stack* nil
  "Stack of active PHP exception handlers.")

(defvar *php-error-handler-stack* nil
  "Stack of active PHP error handlers as (CALLBACK . ERROR-MASK).")

(defvar *php-error-reporting-level* 32767
  "Current PHP error_reporting() level.")

(defun %php-current-exception-handler ()
  "Return the active PHP exception handler, or NIL."
  (first *php-exception-handler-stack*))

(defun %php-current-error-handler ()
  "Return the active PHP error handler entry, or NIL."
  (first *php-error-handler-stack*))

(defun %php-trigger-error (message &optional (error-type 256))
  "PHP trigger_error: generate a user-level error."
  (let* ((errno (funcall (%PARSER-PHP-RUNTIME-SYMBOL :parse-integer-setting) error-type 256))
         (handler-entry (%php-current-error-handler))
         (reportable-p (logtest errno *php-error-reporting-level*))
         (handled-p nil))
    (when (and reportable-p handler-entry (logtest errno (cdr handler-entry)))
      (unless *php-error-callable-resolver*
        (error "PHP error callable resolver is not registered."))
      (let ((fn (funcall *php-error-callable-resolver* (car handler-entry))))
        (when fn
          (setf handled-p
                (funcall (%PARSER-PHP-RUNTIME-SYMBOL :truthy) (funcall fn errno (funcall (%PARSER-PHP-RUNTIME-SYMBOL :stringify) message) nil nil))))))
    (unless (or handled-p (not reportable-p))
      ;; User-triggered errors (E_USER_*) report to stdout so trigger_error() is
      ;; observable in program output; engine-generated diagnostics (E_DEPRECATED,
      ;; E_WARNING, …) go to stderr as PHP's CLI SAPI does, keeping them out of
      ;; captured program output (e.g. serialize() using __sleep()).
      (if (logtest errno (logior 256 512 1024 16384))
          (format t "~A~%" (funcall (%PARSER-PHP-RUNTIME-SYMBOL :stringify) message))
          (format *error-output* "~A~%" (funcall (%PARSER-PHP-RUNTIME-SYMBOL :stringify) message))))
    t))

(in-package #:cl-cc/php/errors)

(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :trigger-error '%php-trigger-error)
  (register-php-runtime-symbol :exception-object-p '%php-exception-object-p)
  (register-php-runtime-symbol :exception-matches-p '%php-exception-matches-p)
  (register-php-runtime-symbol :exception-value '%php-exception-value))
