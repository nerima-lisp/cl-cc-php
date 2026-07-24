;;;; Runtime helpers for PHP lowering.

(in-package :cl-cc/php)

(defconstant +php-array-order-key+ :__php-array-order
  "Reserved hash-table key storing PHP array insertion order.")

(defconstant +php-array-next-index-key+ :__php-array-next-index
  "Reserved hash-table key storing the next PHP auto-increment index.")

(defvar +php-null+ '%php-null%
  "PHP null sentinel distinct from CL nil.")

(defun %php-seed-by-ref-param-registry
    (&optional (registry (make-hash-table :test #'equal)))
  "Seed REGISTRY with builtin functions that take parameters by reference."
  (setf (gethash (symbol-name '%php-settype) registry) '(0))
  (setf (gethash "settype" registry) '(0))
  (setf (gethash "SETTYPE" registry) '(0))
  registry)

(defparameter *php-by-ref-param-registry*
  (%php-seed-by-ref-param-registry)
  "Maps PHP function name strings to lists of by-reference parameter indices (0-based).")

(defun %php-null-p (x)
  "Return true when X is the PHP null sentinel."
  (eq x +php-null+))

(defun %php-current-closure ()
  "Return the currently executing PHP Closure or signal PHP Error outside one."
  (let ((state cl-cc/vm:*vm-state*))
    (if state
        (let* ((depth (length (cl-cc/vm:vm-call-stack state)))
               (stack (cl-cc/vm::vm-current-closure-stack state)))
          (loop while (and stack (> (caar stack) depth))
                do (pop stack))
          (setf (cl-cc/vm::vm-current-closure-stack state) stack)
          (or (loop for (entry-depth . closure) in stack
                    for tag = (and (cl-cc/vm::%vm-closure-object-p closure)
                                   (cl-cc/vm::vm-closure-dispatch-tag closure))
                    when (and (= entry-depth depth)
                              (cl-cc/vm::%vm-closure-object-p closure)
                              (not (and (consp tag) (eq (car tag) :known-function))))
                      return closure)
              (%php-throw 'error "Current function is not a closure.")))
        (%php-throw 'error "Current function is not a closure."))))

(defun %php-fatal-error (message)
  "Emit a PHP fatal error message and optionally include a VM backtrace."
  (format *error-output* "~&~A~%" message)
  (let ((state cl-cc/vm:*vm-state*))
    (when (and (%php-truthy (%php-ini-get "fatal_error_backtraces"))
               state)
      (cl-cc/vm:vm-print-backtrace state))
    (error 'cl-cc/vm:vm-fatal-error
           :message message
           :print-backtrace-p nil)))

(defun %php-object-table-p (x)
  "Return true when X is a PHP object represented as a property table."
  (and (hash-table-p x)
       (or (nth-value 1 (gethash "__class__" x))
           (nth-value 1 (gethash :__class__ x)))))

(defun %php-value-type (x)
  "Return the PHP runtime value type keyword for X."
  (cond ((%php-null-p x) :null)
        ((null x) :bool)
        ((eq x t) :bool)   ; PHP true; without this, type-of t -> BOOLEAN, so
                           ; gettype(true) was "object" and gettype(5>3) wrong
        ((integerp x) :int)
        ((floatp x) :float)
        ((stringp x) :string)
        ((%php-object-table-p x) :object)
        ((hash-table-p x) :array)
        (t (type-of x))))

(define-condition php-exception (error)
  ((class-name :initarg :class-name :reader php-exception-class-name)
   (value :initarg :value :reader php-exception-value))
  (:report (lambda (condition stream)
             (format stream "PHP exception~@[ of class ~A~]: ~S"
                     (php-exception-class-name condition)
                     (php-exception-value condition)))))

;;; -----------------------------------------------------------------------
;;;  PHP Reference semantics — box pattern
;;; -----------------------------------------------------------------------
;;;
;;; PHP references (&$var) are implemented as single-element vectors (boxes).
;;; The parser emits %php-make-ref at call sites for by-reference arguments,
;;; and callee bodies use %php-deref / %php-ref-set! to read and write through
;;; the box so mutations are visible to the caller after the call returns.

(defstruct (php-ref (:conc-name php-ref-))
  (value nil))

(defun %php-ref-p (x) (php-ref-p x))

(defun %php-make-ref (initial-value)
  "Create a PHP reference box holding INITIAL-VALUE."
  (make-php-ref :value initial-value))

(defun %php-deref (ref)
  "Dereference a PHP reference box, returning its current value."
  (if (php-ref-p ref)
      (php-ref-value ref)
      ref))  ; non-ref passthrough for caller safety

(defun %php-ref-set! (ref new-value)
  "Mutate the PHP reference box REF to hold NEW-VALUE; return NEW-VALUE."
  (if (php-ref-p ref)
      (setf (php-ref-value ref) new-value)
      new-value))

(defun %php-pipe (value callable)
  "Apply PHP 8.5 pipe operator VALUE |> CALLABLE."
  (let ((fn (%php-callable-function callable)))
    (if fn
        (funcall fn value)
        (%php-throw 'type-error
                    "Pipe operator RHS must be a valid callable"))))

;;; -----------------------------------------------------------------------
;;;  foreach by-reference iteration
;;; -----------------------------------------------------------------------

(defun %php-foreach-by-ref (arr body-fn)
  "Iterate PHP ordered array ARR calling BODY-FN(box key) for each element.
BODY-FN receives a ref box wrapping the current value and the key.
After BODY-FN returns the box is written back to the array (mutations propagate)."
  (let ((fn (%php-callable-function body-fn)))
    (when (and fn (hash-table-p arr))
      (dolist (key (gethash +php-array-order-key+ arr))
        (let* ((current-val (gethash key arr +php-null+))
               (box (%php-make-ref current-val)))
          (funcall fn box key)
          ;; Write back mutations
          (let ((new-val (%php-deref box)))
            (unless (eq new-val current-val)
              (setf (gethash key arr) new-val)))))))
  +php-null+)
