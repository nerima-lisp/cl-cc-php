;;;; Runtime helpers for PHP lowering: object clone, generators, and exceptions.

(in-package :cl-cc/php)

;;; -----------------------------------------------------------------------
;;;  PHP Generator — eager evaluation with pre-collected value queue
;;; -----------------------------------------------------------------------
;;;
;;; PHP generators (yield/yield from) collect all yielded values by running
;;; the body thunk with *current-generator* set to a collector object.
;;; This is simpler than thread-based coroutines and correct for finite generators.
;;; Infinite generators would exhaust memory, but they're rare in practice.

(defstruct (php-generator (:conc-name php-gen-))
  values        ; queue (list) of yielded values, innermost first
  return-value  ; the generator's final return value
  done-p)       ; true when all values have been consumed

(defun %php-has-method (instance name-sym)
  "Return true when INSTANCE's class defines a slot/method named NAME-SYM. Used by
the `new C(args)' lowering to call __construct only when it exists — the call
itself runs through the normal method-dispatch (vm-call) path, so the constructor
executes in the right VM context."
  (and (cl-cc/vm::%vm-vector-instance-p instance)
       (let ((class (aref instance 0)))
         (and (hash-table-p class)
              (cl-cc/vm::%vm-slot-vector-index class name-sym)
              t))))

(defun %php-clone (instance)
  "Return PHP's shallow object clone. The parser is responsible for invoking a
class-defined __clone method on the copied object so the call stays inside the
normal VM method-dispatch path."
  (handler-case
      (cl-cc/vm::copy-instance instance)
    (error (condition)
      (error "Cannot clone non-object value ~S: ~A" instance condition))))

(defun %php-clone-with-slot (property)
  "Map a PHP clone-with property key to the VM slot symbol used by class fields."
  (intern (string-upcase (%php-stringify property)) (find-package :cl-cc/php)))

(defun %php-clone-with (instance overrides)
  "Apply PHP 8.5 clone-with property OVERRIDES to already-cloned INSTANCE."
  (unless (hash-table-p overrides)
    (%php-throw 'type-error "clone-with overrides must be an array"))
  (dolist (pair (%php-array-pairs overrides) instance)
    (let* ((slot (%php-clone-with-slot (car pair)))
           (class (and (cl-cc/vm::%vm-vector-instance-p instance)
                       (aref instance 0)))
           (index (and class
                       (cl-cc/vm::%vm-slot-vector-index class slot))))
      (unless (and index (< index (length instance)))
        (%php-throw 'error
                    (format nil "The slot ~S is missing from the cloned object"
                            slot)))
      (setf (aref instance index) (cdr pair)))))

(defun %php-generator-p (x) (php-generator-p x))

(defvar *current-generator* nil
  "Dynamically bound to the collecting generator during host-only evaluation
(e.g. %php-make-generator). Compiled PHP generators instead track the active
generator on a VM-global stack so the bridged %php-yield can find it across the
host/VM boundary — see %php-generator-enter / %php-generator-active.")

(defun %php-make-generator (body-thunk)
  "Create a PHP generator by eagerly running BODY-THUNK and collecting yields.
Host-only path (BODY-THUNK is a Common Lisp function); compiled PHP uses the
%php-generator-enter / %php-generator-exit threading instead."
  (let* ((gen (make-php-generator :values nil :return-value +php-null+ :done-p nil)))
    ;; Run the body, collecting all yielded values
    (let ((*current-generator* gen))
      (handler-case
          (let ((result (funcall body-thunk)))
            (setf (php-gen-return-value gen) result))
        (error (e) (declare (ignore e)))))
    ;; Reverse so we can pop from the front (nreverse gives FIFO order)
    (setf (php-gen-values gen) (nreverse (php-gen-values gen)))
    gen))

(defun %php-generator-stack ()
  "Return the active-generator stack stored on the current VM state's globals.
The stack lets the bridged %php-yield locate the generator being built while the
generator's body executes inside the VM. Returns NIL when no VM state is active."
  (when cl-cc/vm:*vm-current-state*
    (gethash '%php-generator-active-stack
             (cl-cc/vm:vm-global-vars cl-cc/vm:*vm-current-state*))))

(defun (setf %php-generator-stack) (new)
  (when cl-cc/vm:*vm-current-state*
    (setf (gethash '%php-generator-active-stack
                   (cl-cc/vm:vm-global-vars cl-cc/vm:*vm-current-state*))
          new)))

(defun %php-generator-active ()
  "Return the generator currently being built, or NIL.
Prefers the host dynamic binding, then the VM-global stack top."
  (or *current-generator*
      (car (%php-generator-stack))))

(defun %php-generator-enter ()
  "Create a fresh generator, push it on the VM-global active stack, and return
it. Pairs with %php-generator-exit. Threading the generator as a value keeps the
host/VM boundary value-in/value-out (no host->VM callback)."
  (let ((gen (make-php-generator :values nil :return-value +php-null+ :done-p nil)))
    (push gen (%php-generator-stack))
    gen))

(defun %php-generator-exit (gen return-value)
  "Pop GEN off the active stack, finalize its value queue (FIFO) and RETURN-VALUE,
and return GEN. RETURN-VALUE is the PHP function body's value (its `return')."
  (setf (%php-generator-stack) (cdr (%php-generator-stack)))
  (setf (php-gen-values gen) (nreverse (php-gen-values gen)))
  (setf (php-gen-return-value gen) return-value)
  gen)

(defun %php-yield (&optional (value +php-null+))
  "Collect VALUE into the current generator's value queue. Returns null (the
eager model has no `send'). When no generator is active (pure host call with no
VM state), returns a (:yield VALUE) marker for inspection."
  (let ((gen (%php-generator-active)))
    (if gen
        (progn
          (push value (php-gen-values gen))
          +php-null+)
        (list :yield value))))

(defun %php-yield-from (iterable)
  "PHP yield from — delegate to another generator/iterable."
  (let ((gen (%php-generator-active)))
    (if gen
        (if (php-generator-p iterable)
            ;; Collect remaining values from inner generator
            (loop (let ((next (%php-generator-next iterable)))
                    (when (eq next +php-null+) (return (php-gen-return-value iterable)))
                    (%php-yield next)))
            ;; Yield each element of an iterable
            (progn
              (when (hash-table-p iterable)
                (dolist (pair (%php-array-pairs iterable))
                  (%php-yield (cdr pair))))
              +php-null+))
        (list :yield-from iterable))))

(defun %php-generator-next (gen &optional (send-value +php-null+))
  "Pop the next value from GEN's queue. Returns null when done."
  (declare (ignore send-value))
  (cond
    ((php-gen-done-p gen) +php-null+)
    ((null (php-gen-values gen))
     (setf (php-gen-done-p gen) t)
     +php-null+)
    (t (pop (php-gen-values gen)))))

(defun %php-generator-valid (gen)
  "True if generator GEN has more values."
  (and (not (php-gen-done-p gen)) (not (null (php-gen-values gen)))))

(defun %php-generator-get-return (gen)
  "Return the generator's final return value."
  (php-gen-return-value gen))

(defun %php-generator-drain-values (gen)
  "Return GEN's remaining values as a CL list (consumes the generator)."
  (loop while (%php-generator-valid gen)
        collect (%php-generator-next gen)))

(defun %php-foreach-values (iterable)
  "Normalize any PHP ITERABLE into a CL list of VALUES for `foreach ($x as $v)'.
Accepts PHP arrays (hash-tables), generators, and CL lists. foreach lowering
binds its loop list to the result, so this is the single seam that makes foreach
work uniformly over every PHP iterable."
  (cond
    ((php-generator-p iterable) (%php-generator-drain-values iterable))
    ((hash-table-p iterable)    (%php-array-values-list iterable))
    ((listp iterable)           iterable)
    (t (error "PHP foreach: value is not iterable: ~S" iterable))))

(defun %php-foreach-pairs (iterable)
  "Normalize any PHP ITERABLE into a CL list of (KEY . VALUE) pairs for
`foreach ($x as $k => $v)'. PHP arrays keep their keys; generators and plain
lists get sequential integer keys 0,1,2,..."
  (cond
    ((php-generator-p iterable)
     (loop for v in (%php-generator-drain-values iterable)
           for i from 0 collect (cons i v)))
    ((hash-table-p iterable) (%php-array-pairs iterable))
    ((listp iterable)
     (loop for v in iterable for i from 0 collect (cons i v)))
    (t (error "PHP foreach: value is not iterable: ~S" iterable))))

(defun %php-throw (class-name value)
  "Signal VALUE as a PHP exception with CLASS-NAME metadata."
  (error 'php-exception :class-name class-name :value value))

(defun %php-make-exception (class-name value)
  "Return a lightweight PHP exception payload for VM catch/throw lowering."
  (list :php-exception class-name value))

(defun %php-exception-object-p (value)
  "Return true when VALUE is a PHP exception payload or condition."
  (or (typep value 'php-exception)
      (and (consp value) (eq (first value) :php-exception))))

(defun %php-exception-class (value)
  "Return VALUE's PHP exception class metadata when present."
  (cond ((typep value 'php-exception) (php-exception-class-name value))
        ((and (consp value) (eq (first value) :php-exception)) (second value))
        (t nil)))

(defun %php-exception-value (value)
  "Return the thrown PHP exception value from VALUE, preserving non-payloads."
  (cond ((typep value 'php-exception) (php-exception-value value))
        ((and (consp value) (eq (first value) :php-exception)) (third value))
        (t value)))

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
