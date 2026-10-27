;;;; runtime-fibers.lisp — PHP 8.1 Fibers.
;;;;
;;;; Runtime, not parser: Fiber has no syntax of its own, it is an ordinary
;;;; class whose methods happen to be implemented in Lisp. Fiber state lives in
;;;; a struct wrapped in a PHP object hash-table so that `$fiber->start()` goes
;;;; through the existing slot-value method dispatch unchanged, and suspension
;;;; is a CATCH/THROW pair rather than anything the compiler knows about.

(in-package :cl-cc/php)

;;; PHP 8.1 Fibers provide cooperative multitasking:
;;;
;;;   $fiber = new Fiber(function(): void {
;;;     $value = Fiber::suspend('fiber');
;;;     echo "Value: " . $value;
;;;   });
;;;   $value = $fiber->start();
;;;   $fiber->resume('test');
;;;
;;; We keep Fiber state in a struct, wrapped in a PHP object hash-table so
;;; ordinary `$fiber->start()` style method dispatch uses the existing runtime
;;; slot-value path.

(defstruct php-fiber
  "Runtime representation of a PHP 8.1 Fiber."
  callback
  (suspended-p nil)
  (started-p nil)
  (terminated-p nil)
  result
  send-value
  (resume-fn nil))

(defvar *current-fiber* nil
  "Dynamically bound to the currently executing PHP Fiber, or NIL.")

(defun %php-fiber-state (fiber)
  "Return the internal Fiber state struct stored in FIBER."
  (cond
    ((php-fiber-p fiber) fiber)
    ((and (hash-table-p fiber)
          (php-fiber-p (gethash "__fiber__" fiber)))
     (gethash "__fiber__" fiber))
    (t
     (error "PHP Fiber error: expected Fiber object"))))

(defun %php-fiber-method-symbol (name)
  "Return the hash-table key used by VM slot lookup for Fiber method NAME."
  (php-ident-sym name))

(defun %php-fiber-set-method (object name function)
  "Install Fiber method FUNCTION under PHP and VM lookup keys."
  (setf (gethash name object) function
        (gethash (%php-fiber-method-symbol name) object) function)
  object)

(defun %php-fiber-install-methods (object method-specs)
  "Install Fiber methods described by METHOD-SPECS on OBJECT."
  (dolist (spec method-specs object)
    (%php-fiber-set-method object (first spec) (symbol-function (second spec)))))

(defun %php-fiber-started-p (fiber)
  "Return true when FIBER has been started."
  (php-fiber-started-p (%php-fiber-state fiber)))

(defun %php-fiber-suspended-p (fiber)
  "Return true when FIBER is suspended."
  (php-fiber-suspended-p (%php-fiber-state fiber)))

;; %php-fiber-install-methods below only needs each name's implementation
;; SYMBOL (it looks up the function via SYMBOL-FUNCTION), so the table
;; references %php-fiber-start/-resume/-get-return/-started-p/-suspended-p/
;; -running-p/-terminated-p directly — their (fiber ...) parameter lists
;; already match the (self ...) shape a Fiber method call needs, with no
;; forwarding wrapper required.
(defparameter +php-fiber-methods+
  '(("start"        %php-fiber-start)
    ("resume"       %php-fiber-resume)
    ("getReturn"    %php-fiber-get-return)
    ("isStarted"    %php-fiber-started-p)
    ("isSuspended"  %php-fiber-suspended-p)
    ("isRunning"    %php-fiber-running-p)
    ("isTerminated" %php-fiber-terminated-p))
  "PHP Fiber object method names and their Common Lisp implementations.")

(defun %php-fiber-make (callback)
  "Create a new PHP Fiber with CALLBACK as its body."
  (let ((object (make-hash-table :test 'equal))
        (state (make-php-fiber :callback callback)))
    (setf (gethash "__class__" object) "Fiber"
          (gethash "__fiber__" object) state)
    (%php-fiber-install-methods object +php-fiber-methods+)
    object))

(defun %php-fiber-start (fiber &rest args)
  "Start FIBER, passing ARGS to its callback.
Returns the first suspended value or the final return value."
  (setf fiber (%php-fiber-state fiber))
  (when (php-fiber-started-p fiber)
    (error "PHP Fiber error: cannot start a Fiber that has already been started"))
  (setf (php-fiber-started-p fiber) t)
  ;; Run the callback; any calls to %php-fiber-suspend will throw a continuation tag.
  (let* ((callback (%php-callable-function (php-fiber-callback fiber)))
         (result
           (catch '%php-fiber-suspend-tag
             (let ((*current-fiber* fiber))
               (if callback
                   (apply callback args)
                   (error "PHP Fiber error: callback is not callable"))))))
    (cond
      ((and (consp result) (eq (first result) '%php-fiber-suspend-payload))
       (setf (php-fiber-suspended-p fiber) t
             (php-fiber-result fiber) (second result))
       (php-fiber-result fiber))
      (t
       (setf (php-fiber-terminated-p fiber) t
             (php-fiber-result fiber) result)
       result))))

(defun %php-fiber-resume (fiber &optional (value nil))
  "Resume a suspended FIBER, passing VALUE as the return from Fiber::suspend().
Returns the next suspended value or the final return value."
  (setf fiber (%php-fiber-state fiber))
  (unless (php-fiber-suspended-p fiber)
    (error "PHP Fiber error: cannot resume a Fiber that is not suspended"))
  (setf (php-fiber-suspended-p fiber) nil
        (php-fiber-send-value fiber) value)
  (let ((resume-fn (php-fiber-resume-fn fiber)))
    (if resume-fn
        (let ((result (catch '%php-fiber-suspend-tag
                        (let ((*current-fiber* fiber))
                          (funcall resume-fn value)))))
          (cond
            ((and (consp result) (eq (first result) '%php-fiber-suspend-payload))
             (setf (php-fiber-suspended-p fiber) t
                   (php-fiber-result fiber) (second result))
             (php-fiber-result fiber))
            (t
             (setf (php-fiber-terminated-p fiber) t
                   (php-fiber-result fiber) result)
             result)))
        ;; No resume fn: fiber was started but suspended without CPS — return sent value
        (progn
          (setf (php-fiber-terminated-p fiber) t)
          +php-null+))))

(defun %php-fiber-suspend (value)
  "Suspend the current PHP Fiber, returning VALUE to the caller.
Must be called from within a running Fiber body."
  (unless *current-fiber*
    (error "PHP Fiber error: Fiber::suspend() called outside of a Fiber"))
  (throw '%php-fiber-suspend-tag (list '%php-fiber-suspend-payload value)))

(defun %php-fiber-get-return (fiber)
  "Return the final return value of a terminated FIBER."
  (setf fiber (%php-fiber-state fiber))
  (unless (php-fiber-terminated-p fiber)
    (error "PHP Fiber error: cannot get return value of a Fiber that has not terminated"))
  (php-fiber-result fiber))

(defun %php-fiber-running-p (fiber)
  "Return true when FIBER is currently executing."
  (setf fiber (%php-fiber-state fiber))
  (and (php-fiber-started-p fiber)
       (not (php-fiber-suspended-p fiber))
       (not (php-fiber-terminated-p fiber))))

(defun %php-fiber-terminated-p (fiber)
  "Return true when FIBER has finished execution."
  (php-fiber-terminated-p (%php-fiber-state fiber)))

;;; ─── Late registrations (after php84 functions are defined) ─────────────────

(eval-when (:load-toplevel :execute)
  ;; PHP 8.1 Fiber builtins.
  (%php-register-builtin "fiber_create"     '%php-fiber-make)
  (%php-register-builtin "fiber_start"      '%php-fiber-start)
  (%php-register-builtin "fiber_resume"     '%php-fiber-resume)
  (%php-register-builtin "fiber_suspend"    '%php-fiber-suspend)
  (%php-register-builtin "fiber_get_return" '%php-fiber-get-return))
