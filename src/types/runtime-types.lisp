;;;; Runtime helpers for PHP lowering.

(in-package #:cl-cc/php/types)

(defvar +php-null+ '%php-null%
  "PHP null sentinel distinct from CL nil.")

(defun %php-null-p (x)
  "Return true when X is the PHP null sentinel."
  (eq x +php-null+))

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

(in-package #:cl-cc/php/types)

(progn
  (defvar *php-array-empty-predicate* nil
    "Callback for PHP ordered-array emptiness.")

  (defun register-php-array-empty-predicate (predicate)
    "Register the PHP ordered-array emptiness predicate."
    (check-type predicate function)
    (when *php-array-empty-predicate*
      (error "PHP array emptiness predicate is already registered."))
    (setf *php-array-empty-predicate* predicate))

  (defun %php-truthy (value)
    "Return VALUE interpreted according to PHP truthiness rules."
    (cond ((%php-null-p value) nil)
          ((null value) nil)
          ((and (integerp value) (zerop value)) nil)
          ((and (floatp value) (zerop value)) nil)
          ((and (stringp value) (or (string= value "") (string= value "0"))) nil)
          ((%php-object-table-p value) t)
          ((and (hash-table-p value)
                (if *php-array-empty-predicate*
                    (funcall *php-array-empty-predicate* value)
                  (zerop (hash-table-count value)))) nil)
          (t t))))

(in-package #:cl-cc/php/types)

(defun %php-number-to-string (n)
  "Format a PHP number the way echo / string interpolation does: integers as-is,
floats (and the rationals PHP / can produce) with up to 14 significant digits,
trailing zeros trimmed, no exponent marker — and a whole-valued float prints as
an integer (3.0 -> \"3\").  princ-to-string leaked the CL form: \"1.5d0\", \"5/2\"."
  (cond
    ((integerp n) (princ-to-string n))
    (t
     (let ((d (coerce n 'double-float)))
       (cond
         ;; whole-valued within the integer-printable range
         ((and (= d (ftruncate d)) (< (abs d) 1d15))
          (princ-to-string (truncate d)))
         (t
          ;; 14 fractional digits then trim trailing zeros (whole case handled
          ;; above, so a fractional digit always remains).
          (let* ((s (format nil "~,14F" d))
                 (dot (position #\. s)))
            (if dot
                (let ((end (1+ (position-if (lambda (c) (char/= c #\0)) s :from-end t))))
                  (subseq s 0 (max end (+ dot 2))))
                s))))))))

(in-package #:cl-cc/php/types)

(defun %php-stringify (value)
  "Convert VALUE to PHP's simple string representation for interpolation."
  (cond ((%php-null-p value) "")
        ((null value) "")
        ((eq value t) "1")
        ((stringp value) value)
        ((numberp value) (%php-number-to-string value))
        ((hash-table-p value) "Array")
        (t (princ-to-string value))))

(in-package #:cl-cc/php/types)

(defstruct (php-ref (:conc-name php-ref-))
  (value nil))  ; Non-reference values pass through unchanged.

(defun %php-deref (ref)
  "Dereference a PHP reference box, returning its current value."
  (if (php-ref-p ref)
      (php-ref-value ref)
      ref))

(defun %php-make-ref (initial-value)
  "Create a PHP reference box holding INITIAL-VALUE."
  (make-php-ref :value initial-value))

;;; -----------------------------------------------------------------------
;;;  PHP Reference semantics — box pattern
;;; -----------------------------------------------------------------------
;;;
;;; PHP references (&$var) are implemented as single-element vectors (boxes).
;;; The parser emits %php-make-ref at call sites for by-reference arguments,
;;; and callee bodies use %php-deref / %php-ref-set! to read and write through
;;; the box so mutations are visible to the caller after the call returns.

(defun %php-ref-p (x) (php-ref-p x))

(defun %php-ref-set! (ref new-value)
  "Mutate the PHP reference box REF to hold NEW-VALUE; return NEW-VALUE."
  (if (php-ref-p ref)
      (setf (php-ref-value ref) new-value)
      new-value))

(in-package #:cl-cc/php/types)

(defun %php-parse-integer-setting (value fallback)
  (handler-case
      (parse-integer (%php-stringify value) :junk-allowed t)
    (error () fallback)))

(eval-when (:load-toplevel :execute) (register-php-runtime-symbol :truthy '%php-truthy) (register-php-runtime-symbol :stringify '%php-stringify))

(eval-when (:load-toplevel :execute) (register-php-runtime-symbol :parse-integer-setting '%php-parse-integer-setting))
