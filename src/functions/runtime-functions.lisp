(in-package #:cl-cc/php/functions)

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

(defun %php-seed-by-ref-param-registry
    (&optional (registry (make-hash-table :test #'equal)))
  "Seed REGISTRY with builtin functions that take parameters by reference."
  (setf (gethash "%PHP-SETTYPE" registry) '(0))
  (setf (gethash "settype" registry) '(0))
  (setf (gethash "SETTYPE" registry) '(0))
  (setf (gethash "%PHP-SIMILAR-TEXT" registry) '(2))
  (setf (gethash "similar_text" registry) '(2))
  (setf (gethash "SIMILAR_TEXT" registry) '(2))
  registry)

(defparameter *php-by-ref-param-registry*
  (%php-seed-by-ref-param-registry)
  "Maps PHP function name strings to lists of by-reference parameter indices (0-based).")
(progn
  (defun %PARSER-PHP-INITIALIZE-SOURCE-STATE ()
    (list (cons '*php-by-ref-param-registry*
                (%php-seed-by-ref-param-registry))
          (cons '*php-named-param-registry*
                (make-hash-table :test #'equal))))
  (eval-when (:load-toplevel :execute)
    (register-php-source-state-initializer
     (function %PARSER-PHP-INITIALIZE-SOURCE-STATE))
    (register-php-source-finalizer
     40
     (lambda (forms)
       (%php-lower-reference-assignments forms nil)))))

(in-package #:cl-cc/php/functions)

(defun %php-callable-user-function (name)
  "Resolve PHP user-function NAME (a string) to a callable via the VM function
registry, or NIL.  PHP function names are case-insensitive; the compiler interns
each into whatever *package* was current at parse time, so matching by EQ symbol
is fragile across the host/VM boundary.  Match by SYMBOL-NAME (upcased) instead,
which is package-independent.  A registry hit that is a vm-closure-object is
wrapped in the same %vm-call-closure-sync trampoline used for Closure args."
  (let ((state cl-cc/vm:*vm-state*))
    (when (and state (stringp name))
      (let ((target (string-upcase name))
            (registry (cl-cc/vm:vm-function-registry state)))
        (block found
          (maphash (lambda (sym fn)
                     (when (and (symbolp sym)
                                (string= (symbol-name sym) target))
                       (return-from found
                         (if (cl-cc/vm::%vm-closure-object-p fn)
                             (lambda (&rest args)
                               (cl-cc/vm::%vm-call-closure-sync fn state args))
                             fn))))
                   registry)
          nil)))))

(defvar *php-builtin-function-resolver* nil)
(defun %php-callable-function (callback)
  "Resolve CALLBACK to a Common Lisp function, or NIL.

A compiled-PHP closure (Closure object / arrow fn) is a vm-closure-object, which
host CL:FUNCALL cannot call. Wrap it in a trampoline that routes back into the VM
via %vm-call-closure-sync, using *vm-state* (dynamically bound around VM
execution for exactly this host-runtime -> VM-closure inverse bridge). Mirrors the
JS *js-apply-fn* installer. Without this, array_map/array_filter/array_reduce/
usort with a closure callback silently no-op (the resolver returned NIL)."
  (cond ((functionp callback) callback)
        ((cl-cc/vm::%vm-closure-object-p callback)
         (lambda (&rest args)
           (cl-cc/vm::%vm-call-closure-sync callback cl-cc/vm:*vm-state* args)))
        ((and (symbolp callback) (fboundp callback)) (symbol-function callback))
        ((stringp callback)
         ;; A string callable names a global function.  Try builtins first, then
         ;; the VM function registry for USER functions (function foo(){...}).
         (or (and *php-builtin-function-resolver* (funcall *php-builtin-function-resolver* callback)) (%php-callable-user-function callback)))
        (t nil)))

(defun %PARSER-PHP-CLOSURE-STATIC-MEMBER-LOWERER (object member args method-p)
  (if (and method-p
           (ast-var-p object)
           (string= (string-upcase (symbol-name (ast-var-name object))) "CLOSURE")
           (string= (string-upcase (symbol-name member)) "GETCURRENT"))
      (progn
        (when args
          (error "PHP parse error: Closure::getCurrent() expects no arguments"))
        (values
         (make-ast-call
          :func (make-ast-var :name (%PARSER-PHP-RUNTIME-SYMBOL :current-closure))
          :args nil)
         t))
      (values nil nil)))

(defun register-php-builtin-function-resolver (resolver) (setf *php-builtin-function-resolver* resolver))

(defvar *php-builtin-symbol-resolver* nil)

(defun register-php-builtin-symbol-resolver (resolver) (setf *php-builtin-symbol-resolver* resolver))

(defun %php-lookup-builtin-symbol (name) (when *php-builtin-symbol-resolver* (funcall *php-builtin-symbol-resolver* name)))

(eval-when (:load-toplevel :execute) (register-php-array-callable-resolver #'%php-callable-function))

(defvar *php-parameter-modifier-parser* nil)

(defun register-php-parameter-modifier-parser (parser) (setf *php-parameter-modifier-parser* parser))

(defun %PARSER-PHP-PARSE-PARAMETER-MODIFIERS (stream) (if *php-parameter-modifier-parser* (funcall *php-parameter-modifier-parser* stream) (values nil stream)))

(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :current-closure '%php-current-closure)
  (register-php-expression-static-member-lowerer
   #'%PARSER-PHP-CLOSURE-STATIC-MEMBER-LOWERER))

(eval-when (:load-toplevel :execute)
  (register-php-error-callable-resolver (function %php-callable-function))
  (register-php-expression-callable-resolver (function %php-callable-function)))

(in-package #:cl-cc/php/functions)

(defvar *php-missing-call-arg* (list :php-missing-call-arg))

(defun %php-call-args-with-named-spread
    (fn-name param-names default-present default-values &rest descriptors)
  "Return a runtime positional argument list for calls that mix ...spread and
named arguments when the spread width is not statically known."
  (let ((positional nil)
        (named (make-hash-table :test #'equal))
        (seen-named nil)
        (highest-named-index -1))
    (labels ((param-index (name)
               (position name param-names :test #'string-equal))
             (push-positional (value)
               (when seen-named
                 (error "PHP positional argument after named argument in call to ~A"
                        fn-name))
               (push value positional)))
      (dolist (descriptor descriptors)
        (destructuring-bind (kind &rest values) descriptor
          (case kind
            (:pos
             (push-positional (first values)))
            (:spread
             (when seen-named
               (error "PHP spread argument after named argument in call to ~A"
                      fn-name))
             (dolist (value (%php-array-values-list (first values)))
               (push value positional)))
            (:named
             (setf seen-named t)
             (destructuring-bind (name value) values
               (let ((index (param-index name)))
                 (unless index
                   (error "Unknown named argument ~A for PHP function ~A"
                          name fn-name))
                 (multiple-value-bind (old present-p) (gethash name named)
                   (declare (ignore old))
                   (when present-p
                     (error "Duplicate named argument ~A for PHP function ~A"
                            name fn-name)))
                 (setf (gethash name named) value
                       highest-named-index (max highest-named-index index)))))
            (otherwise
              (error "Unknown PHP call argument descriptor ~S" kind)))))
      (let* ((positional (nreverse positional))
             (positional-count (length positional))
             (result-size (max positional-count (1+ highest-named-index)))
             (result (make-array result-size
                                 :initial-element *php-missing-call-arg*)))
        (loop for value in positional
              for index from 0
              do (setf (aref result index) value))
        (maphash (lambda (name value)
                   (let ((index (param-index name)))
                     (when (< index positional-count)
                       (error "Duplicate PHP argument for parameter ~A in call to ~A"
                              name fn-name))
                     (setf (aref result index) value)))
                 named)
        (loop for index below result-size
              for value = (aref result index)
              collect (cond
                        ((not (eq value *php-missing-call-arg*)) value)
                        ((nth index default-present)
                         (nth index default-values))
                        (t
                         (error "Missing PHP argument ~A for function ~A"
                                (nth index param-names) fn-name))))))))
