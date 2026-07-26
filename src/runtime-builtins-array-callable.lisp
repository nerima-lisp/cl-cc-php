;;;; runtime-builtins-array-callable.lisp — PHP callables and callback-driven
;;;; array builtins.
;;;;
;;;; Two things that are really one concern: turning a PHP "callable" (a Closure
;;;; object, a function-name string, a host function) into something CL:FUNCALL
;;;; can invoke, and every array builtin whose behaviour is decided by such a
;;;; callback — array_map/filter/reduce/walk, the u* comparison variants, and
;;;; the PHP 8.4 array_find/any/all family.
;;;;
;;;; Kept out of runtime-builtins-array.lisp because the callback path drags in
;;;; the VM closure trampoline (cl-cc/vm) that the plain sequence operations
;;;; have no business knowing about.

(in-package :cl-cc/php)

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
         (or (and (fboundp '%php-lookup-builtin)
                  (funcall (symbol-function '%php-lookup-builtin) callback))
             (%php-callable-user-function callback)))
        (t nil)))
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
(defun %php-call-user-func (callback &rest args)
  "PHP call_user_func: invoke CALLBACK (Closure, function-name string, or a host
function) with ARGS and return the result."
  (let ((fn (%php-callable-function callback)))
    (if fn
        (apply fn args)
        (%php-throw 'type-error
                    "call_user_func(): Argument #1 ($callback) must be a valid callback"))))
(defun %php-call-user-func-array (callback args-array)
  "PHP call_user_func_array: invoke CALLBACK with the values of PHP ARGS-ARRAY
spread as positional arguments."
  (let ((fn (%php-callable-function callback)))
    (if fn
        (apply fn (if (hash-table-p args-array)
                      (%php-array-values-list args-array)
                      nil))
        (%php-throw 'type-error
                    "call_user_func_array(): Argument #1 ($callback) must be a valid callback"))))
;;; ─── Callback-driven traversal ──────────────────────────────────────────────

(defun %php-array-map (callback array &rest more-arrays)
  "Apply CALLBACK across one or more PHP arrays.
PHP preserves keys only when exactly one array is supplied; multiple arrays are
zipped by position and reindexed. A null callback returns the original values
for one array and row arrays for multiple arrays."
  (let* ((arrays (cons array more-arrays))
         (fn (and (not (%php-null-p callback))
                  (%php-callable-function callback)))
         (result (%php-array)))
    (cond
      ((some (lambda (arr) (not (hash-table-p arr))) arrays)
       result)
      ((null more-arrays)
       (dolist (pair (%php-array-pairs array) result)
         (%php-array-set result (car pair)
                         (if fn (funcall fn (cdr pair)) (cdr pair)))))
      (t
       (let* ((lists (mapcar #'%php-array-values-list arrays))
              (limit (if lists (apply #'max (mapcar #'length lists)) 0)))
         (loop for i below limit
               for args = (mapcar (lambda (lst)
                                     (if (< i (length lst)) (nth i lst) +php-null+))
                                   lists)
               do (if fn
                      (%php-array-set result (%php-array-next-auto-index result)
                                      (apply fn args))
                      (let ((row (%php-array)))
                        (dolist (arg args)
                          (%php-array-set row (%php-array-next-auto-index row) arg))
                        (%php-array-set result (%php-array-next-auto-index result) row))))
         result)))))
(defun %php-array-map-multi (callback &rest arrays)
  "PHP array_map with multiple arrays: maps CALLBACK over parallel elements."
  (if arrays
      (apply #'%php-array-map callback arrays)
      (%php-array)))
(defun %php-array-filter (array &optional callback (mode 0))
  "Filter ARRAY values by CALLBACK or PHP truthiness.

MODE follows PHP's array_filter flags:
0 = pass value, ARRAY_FILTER_USE_BOTH(1) = pass value and key,
ARRAY_FILTER_USE_KEY(2) = pass key."
  (let ((fn (and callback (not (%php-null-p callback)) (%php-callable-function callback)))
        (result (%php-array)))
    (when (hash-table-p array)
      (dolist (pair (%php-array-pairs array))
        (let ((keep (if fn
                        (case mode
                          (1 (funcall fn (cdr pair) (car pair)))
                          (2 (funcall fn (car pair)))
                          (otherwise (funcall fn (cdr pair))))
                        (%php-truthy (cdr pair)))))
          (when (%php-truthy keep)
            (%php-array-set result (car pair) (cdr pair))))))
    result))
(defun %php-array-reduce (array callback &optional initial)
  "Reduce ARRAY values with CALLBACK and optional INITIAL accumulator."
  (let ((fn (%php-callable-function callback))
        (acc (if (or (null initial) (%php-null-p initial)) +php-null+ initial)))
    (when (and fn (hash-table-p array))
      (dolist (value (%php-array-values-list array))
        (setf acc (funcall fn acc value))))
    acc))
(defun %php-array-walk (array callback &optional extra-data)
  "PHP array_walk: call CALLBACK(value, key, extra?) for each element."
  (let ((fn (%php-callable-function callback)))
    (when fn
      (dolist (pair (%php-array-pairs array))
        (if extra-data
            (funcall fn (cdr pair) (car pair) extra-data)
            (funcall fn (cdr pair) (car pair))))))
  t)
;;; ─── User-comparison (u*) set operations ────────────────────────────────────

(defun %php-callback-equal-p (cb value items)
  "True when VALUE compares equal (callback returns 0) to some element of the
CL list ITEMS, using the user comparison callback CB."
  (and cb (some (lambda (o) (zerop (%php-numeric (funcall cb value o)))) items)))
(defun %php-array-udiff (array &rest rest)
  "PHP array_udiff: elements of ARRAY not found in the other arrays, compared by
the LAST argument — a callback ($a,$b) -> negative/0/positive (0 means equal)."
  (let* ((cb (%php-callable-function (car (last rest))))
         (others (loop for a in (butlast rest)
                       when (hash-table-p a) append (mapcar #'cdr (%php-array-pairs a))))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (unless (%php-callback-equal-p cb (cdr pair) others)
        (%php-array-set result (car pair) (cdr pair))))
    result))
(defun %php-array-uintersect (array &rest rest)
  "PHP array_uintersect: elements of ARRAY present in ALL other arrays, compared
by the last argument (a user comparison callback)."
  (let* ((cb (%php-callable-function (car (last rest))))
         (arrays (remove-if-not #'hash-table-p (butlast rest)))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (when (and cb (every (lambda (a)
                             (%php-callback-equal-p cb (cdr pair) (mapcar #'cdr (%php-array-pairs a))))
                           arrays))
        (%php-array-set result (car pair) (cdr pair))))
    result))
;;; ─── PHP 8.4 search predicates ──────────────────────────────────────────────

(defun %php-array-find (arr callback)
  "Return the first element of ARR for which CALLBACK returns true, or PHP null.
PHP 8.4: array_find()."
  (let ((fn (%php-callable-function callback)))
    (when (and fn (hash-table-p arr))
      (dolist (pair (%php-array-pairs arr))
        (when (%php-truthy (funcall fn (cdr pair)))
          (return-from %php-array-find (cdr pair)))))
    +php-null+))
(defun %php-array-find-key (arr callback)
  "Return the key of the first element for which CALLBACK returns true, or PHP null.
PHP 8.4: array_find_key()."
  (let ((fn (%php-callable-function callback)))
    (when (and fn (hash-table-p arr))
      (dolist (pair (%php-array-pairs arr))
        (when (%php-truthy (funcall fn (cdr pair)))
          (return-from %php-array-find-key (car pair)))))
    +php-null+))
(defun %php-array-any (arr callback)
  "Return true when CALLBACK returns true for at least one element of ARR.
PHP 8.4: array_any()."
  (let ((fn (%php-callable-function callback)))
    (and fn
         (hash-table-p arr)
         (some (lambda (pair) (%php-truthy (funcall fn (cdr pair))))
               (%php-array-pairs arr)))))
(defun %php-array-all (arr callback)
  "Return true when CALLBACK returns true for every element of ARR.
PHP 8.4: array_all(). Returns true for an empty array."
  (let ((fn (%php-callable-function callback)))
    (or (not fn)
        (not (hash-table-p arr))
        (every (lambda (pair) (%php-truthy (funcall fn (cdr pair))))
               (%php-array-pairs arr)))))
