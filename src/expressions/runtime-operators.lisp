;;;; Runtime helpers for PHP lowering: value coercion and operators.

(in-package #:cl-cc/php/expressions)

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

(defun %php-add (a b)
  "PHP + : array UNION when both operands are arrays (left keys win, keys
preserved), otherwise numeric addition with operand coercion."
  (if (and (hash-table-p a) (hash-table-p b))
      (call-php-array-expression-lowerer :union a b)
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

(define-php-int-binop %php-modulo     rem
                       "Return A % B using PHP-style integer truncation toward zero.")

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

(define-php-int-binop %php-bitwise-and logand
                       "Return PHP bitwise AND for integer-coerced operands.")

(define-php-int-binop %php-bitwise-or  logior "Return PHP bitwise OR for integer-coerced operands.")

(define-php-int-binop %php-bitwise-xor logxor
                       "Return PHP bitwise XOR for integer-coerced operands.")

(defun %php-bitwise-not (a)
  "Return PHP bitwise NOT for an integer-coerced operand."
  (lognot (%php-to-integer a)))

(defun %php-isset (var)
  "Return true when symbol VAR is bound."
  (check-type var symbol)
  (boundp var))

(defun %php-pipe (value callable)
  "Apply PHP 8.5 pipe operator VALUE |> CALLABLE."
  (let ((fn (call-php-expression-callable-resolver callable)))
    (if fn
        (funcall fn value)
        (%php-throw 'type-error
                    "Pipe operator RHS must be a valid callable"))))

(in-package #:cl-cc/php/expressions)

(defun %php-concat (&rest values)
  "Concatenate VALUES after PHP-style string conversion."
  (apply #'concatenate 'string (mapcar #'%php-stringify values)))
(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :concat '%php-concat))
