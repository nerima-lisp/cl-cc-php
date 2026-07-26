;;;; Runtime helpers for PHP lowering: value coercion, operators, and enums.

(in-package :cl-cc/php)

(defun %php-truthy (value)
  "Return VALUE interpreted according to PHP truthiness rules."
  (cond ((%php-null-p value) nil)
        ((null value) nil)
        ((and (integerp value) (zerop value)) nil)
        ((and (floatp value) (zerop value)) nil)
        ((and (stringp value) (or (string= value "") (string= value "0"))) nil)
        ((%php-object-table-p value) t)
        ((and (hash-table-p value) (%php-array-empty-p value)) nil)
        (t t)))

(defun %php-numeric (x)
  "PHP numeric coercion for an arithmetic operand: number -> itself, null -> 0,
true -> 1, false -> 0, string -> its leading numeric value (%php-to-number).
Without this, PHP +,-,* lowered to raw CL arithmetic and errored on any non-
number operand (null + 3, '5' + 3, true + 1 all signalled `not of type NUMBER')."
  (cond ((numberp x) x)
        ((%php-null-p x) 0)
        ((eq x t) 1)
        ((null x) 0)
        ((stringp x) (%php-to-number x))
        (t 0)))

(defun %php-array-union (a b)
  "PHP array + : a new array with all of A's entries (keys preserved), plus B's
entries whose keys are not already present in A — the LEFT operand wins on key
conflicts.  Unlike array_merge, integer keys are NOT reindexed."
  (let ((result (%php-array))
        (a-keys (gethash +php-array-order-key+ a)))
    (dolist (pair (%php-array-pairs a))
      (%php-array-set result (car pair) (cdr pair)))
    (dolist (pair (%php-array-pairs b))
      (unless (member (car pair) a-keys :test #'equal)
        (%php-array-set result (car pair) (cdr pair))))
    result))

(defun %php-add (a b)
  "PHP + : array UNION when both operands are arrays (left keys win, keys
preserved), otherwise numeric addition with operand coercion."
  (if (and (hash-table-p a) (hash-table-p b))
      (%php-array-union a b)
      (+ (%php-numeric a) (%php-numeric b))))

(defun %php-unary-plus (value)
  "PHP unary + with the same numeric coercion used by arithmetic operands."
  (%php-numeric value))

(defun %php-unary-minus (value)
  "PHP unary - with the same numeric coercion used by arithmetic operands."
  (- (%php-numeric value)))

(defun %php-sub (a b) "PHP - with operand coercion." (- (%php-numeric a) (%php-numeric b)))

(defun %php-mul (a b) "PHP * with operand coercion." (* (%php-numeric a) (%php-numeric b)))

(defun %php-div (a b)
  "PHP / : returns a float, EXCEPT when both operands are integers and evenly
divisible (then an integer).  Was the CL / operator, which yielded an exact
rational (10 / 4 -> 5/2, printed \"5/2\")."
  (let ((na (%php-numeric a))
        (nb (%php-numeric b)))
    (if (and (integerp na) (integerp nb) (not (zerop nb)) (zerop (mod na nb)))
        (truncate na nb)
        (/ (coerce na 'double-float) (coerce nb 'double-float)))))

(defun %php-to-number (s)
  "Coerce PHP string S to a number for loose comparisons."
  (check-type s string)
  (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) s)))
    (cond ((string= trimmed "") 0)
          ((find-if (lambda (ch) (member ch '(#\. #\e #\E))) trimmed)
           (handler-case
               (let ((value (read-from-string trimmed)))
                 (if (numberp value) value 0))
             (error () 0)))
          (t
           (handler-case
               (or (parse-integer trimmed :junk-allowed t) 0)
             (error () 0))))))

(defun %php-eq-strict (a b)
  "Return true when A and B are equal according to PHP === semantics."
  (let ((type-a (%php-value-type a))
        (type-b (%php-value-type b)))
    (and (eq type-a type-b)
         (case type-a
           (:null t)
           (:bool (eq a b))
           ((:int :float :string) (equal a b))
           (:array (eq a b))
           (otherwise (equal a b))))))

(defun %php-eq-loose (a b)
  "Return true when A and B are equal according to PHP == semantics."
  (let ((type-a (%php-value-type a))
        (type-b (%php-value-type b)))
    (cond ((and (eq type-a :bool) (eq type-b :bool))
           (eq a b))
          ((or (eq type-a :bool) (eq type-b :bool)
               (eq type-a :null) (eq type-b :null))
           (eq (%php-truthy a) (%php-truthy b)))
          ((and (member type-a '(:int :float)) (member type-b '(:int :float)))
           (= a b))
          ((and (eq type-a :string) (member type-b '(:int :float)))
           (= (%php-to-number a) b))
          ((and (member type-a '(:int :float)) (eq type-b :string))
           (= a (%php-to-number b)))
          ((and (eq type-a :string) (eq type-b :string))
           (if (or (string= a "") (string= b ""))
               (= (%php-to-number a) (%php-to-number b))
               (%php-eq-strict a b)))
          (t (%php-eq-strict a b)))))

(defun %php-neq-loose (a b)
  "PHP != / <> : the negation of loose equality."
  (not (%php-eq-loose a b)))

(defun %php-neq-strict (a b)
  "PHP !== : the negation of strict equality."
  (not (%php-eq-strict a b)))

(defun %php-strlen (s)
  "Return the length of string S."
  (check-type s string)
  (length s))

(defun %php-strtolower (s)
  "Return S converted to lowercase."
  (check-type s string)
  (string-downcase s))

(defun %php-strtoupper (s)
  "Return S converted to uppercase."
  (check-type s string)
  (string-upcase s))

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

(defun %php-stringify (value)
  "Convert VALUE to PHP's simple string representation for interpolation."
  (cond ((%php-null-p value) "")
        ((null value) "")
        ((eq value t) "1")
        ((stringp value) value)
        ((numberp value) (%php-number-to-string value))
        ((hash-table-p value) "Array")
        (t (princ-to-string value))))

(defun %php-concat (&rest values)
  "Concatenate VALUES after PHP-style string conversion."
  (apply #'concatenate 'string (mapcar #'%php-stringify values)))

(defun %php-to-integer (value)
  "Coerce VALUE to an integer for PHP arithmetic/bitwise helpers."
  (cond ((integerp value) value)
        ((floatp value) (truncate value))
        ((stringp value) (truncate (%php-to-number value)))
        ((%php-null-p value) 0)
        ((null value) 0)
        ((eq value t) 1)
        (t (truncate value))))

(defmacro define-php-int-binop (name op &optional doc)
  "Define binary PHP helper NAME applying OP to both operands coerced via %PHP-TO-INTEGER."
  `(defun ,name (a b) ,@(when doc (list doc))
     (,op (%php-to-integer a) (%php-to-integer b))))

(defmacro define-php-comparison (name cmp &optional doc)
  "Define binary PHP relational helper NAME, returning a PHP boolean by comparing
the %PHP-SPACESHIP result against 0 with CMP."
  `(defun ,name (a b) ,@(when doc (list doc))
     (and (,cmp (%php-spaceship a b) 0) t)))

(define-php-int-binop %php-modulo     rem "Return A % B using PHP-style integer truncation toward zero.")

(define-php-int-binop %php-shift-left ash "Return A shifted left by B bits.")

(defun %php-shift-right (a b)
  "Return A shifted right by B bits, preserving sign for negative integers."
  (ash (%php-to-integer a) (- (%php-to-integer b))))

(defun %php-spaceship (a b)
  "Return -1, 0, or 1 according to PHP <=> comparison ordering."
  (cond ((%php-eq-loose a b) 0)
        ((and (numberp a) (numberp b)) (if (< a b) -1 1))
        ((and (stringp a) (stringp b)) (cond ((string< a b) -1)
                                             ((string> a b) 1)
                                             (t 0)))
        ((and (stringp a) (numberp b)) (if (< (%php-to-number a) b) -1 1))
        ((and (numberp a) (stringp b)) (if (< a (%php-to-number b)) -1 1))
        (t (if (string< (%php-stringify a) (%php-stringify b)) -1 1))))

;;; Relational operators return a PHP boolean (t / nil), NOT 1 / 0.  They lower
;;; through these helpers rather than a plain ast-binop (CL <,>) because the VM
;;; comparison yields an INTEGER 1/0, so `5 > 3' had type integer — gettype(5>3)
;;; was "integer", (5>3) === true was false, and match(true){$x>3=>…} never
;;; matched.  Deriving from %php-spaceship also gives correct PHP comparison
;;; semantics (numeric strings, type juggling) for free.
(define-php-comparison %php-lt <  "PHP a < b.")

(define-php-comparison %php-gt >  "PHP a > b.")

(define-php-comparison %php-le <= "PHP a <= b.")

(define-php-comparison %php-ge >= "PHP a >= b.")

(define-php-int-binop %php-bitwise-and logand "Return PHP bitwise AND for integer-coerced operands.")

(define-php-int-binop %php-bitwise-or  logior "Return PHP bitwise OR for integer-coerced operands.")

(define-php-int-binop %php-bitwise-xor logxor "Return PHP bitwise XOR for integer-coerced operands.")

(defun %php-bitwise-not (a)
  "Return PHP bitwise NOT for an integer-coerced operand."
  (lognot (%php-to-integer a)))

(defun %php-isset (var)
  "Return true when symbol VAR is bound."
  (check-type var symbol)
  (boundp var))

(defun %php-enum-make-case (enum-name case-name value)
  "Create a PHP enum case singleton payload.  `name' and `value' are stored under
STRING keys so $case->name / $case->value resolve through the slot-read string-
key fallback (a symbol key would require the runtime-interned property symbol to
land in the same package, which it does not reliably)."
  ;; :test #'equal — the slot-read string-key fallback looks up "name"/"value"
  ;; with a freshly built string, which is not EQ to the stored key; equal makes
  ;; both the string property keys and the keyword internal keys resolve.
  (let ((case (make-hash-table :test #'equal)))
    (setf (gethash :__php-enum-case__ case) t
          (gethash :__enum-name__ case) enum-name
          (gethash :__case-name__ case) case-name
          (gethash "value" case) value
          (gethash "name" case) (symbol-name case-name))
    case))

(defun %php-enum-case-p (value)
  "Return true when VALUE is a PHP enum case payload."
  (and (hash-table-p value) (gethash :__php-enum-case__ value)))

(defun %php-enum-finalize (enum-class)
  "Link each of ENUM-CLASS's case singletons to the class via :__class__ so that
$case->method() dispatches through the class.  (Enum methods are stored class-
allocated, so slot-read on a case whose __class__ is the enum class resolves
them.)  Returns ENUM-CLASS."
  (when (hash-table-p enum-class)
    (dolist (case (%php-enum-case-list enum-class))
      (setf (gethash :__class__ case) enum-class)))
  enum-class)

(defun %php-enum-case-list (enum-class)
  "Return ENUM-CLASS's case singleton payloads as a CL list (insertion order)."
  (check-type enum-class hash-table)
  (loop for slot-name in (gethash :__class-slots__ enum-class)
        for slot-value = (gethash slot-name enum-class)
        when (%php-enum-case-p slot-value)
          collect slot-value))

(defun %php-enum-cases (enum-class)
  "Return ENUM::cases() — a PHP ARRAY of the case singletons (so count(), foreach,
etc. work). The previous CL list broke count()/array builtins."
  (%php-list-to-array (%php-enum-case-list enum-class)))

(defun %php-enum-case-value (enum-case)
  "Return ENUM-CASE's backed value, or PHP null for unit cases."
  (check-type enum-case hash-table)
  (gethash "value" enum-case +php-null+))

(defun %php-enum-try-from (enum-class value)
  "Return the backed enum case from ENUM-CLASS matching VALUE, or PHP null."
  (or (find value (%php-enum-case-list enum-class)
            :key #'%php-enum-case-value
            :test #'%php-eq-strict)
      +php-null+))

(defun %php-enum-from (enum-class value)
  "Return the backed enum case from ENUM-CLASS matching VALUE, or signal a PHP ValueError."
  (let ((case (%php-enum-try-from enum-class value)))
    (if (%php-null-p case)
        (%php-throw 'value-error (format nil "No enum case for value ~S" value))
        case)))

;;; ─── Enum case accessors ────────────────────────────────────────────────────

(defun %php-enum-name (enum-case)
  "Return the symbolic name of a PHP enum case."
  (check-type enum-case hash-table)
  (gethash 'name enum-case +php-null+))

(defun %php-enum-p (value)
  "Return true when VALUE is a PHP enum case (backed or unit)."
  (%php-enum-case-p value))
