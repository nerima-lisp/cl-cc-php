;;;; runtime-builtins-types-test.lisp — src/runtime-builtins-types.lisp.
;;;;
;;;; Type predicates, the scalar conversions (intval/floatval/strval/boolval), and settype.

(in-package :cl-cc-php/test)

(describe
  "PHP type predicates"
  (it-sequential-each
    ((cl-cc/php::%php-is-int 42 t)
      (cl-cc/php::%php-is-int 4.2 nil)
      (cl-cc/php::%php-is-int "42" nil)
      (cl-cc/php::%php-is-integer 42 t)
      (cl-cc/php::%php-is-long 42 t)
      (cl-cc/php::%php-is-float 4.2 t)
      (cl-cc/php::%php-is-float 42 nil)
      (cl-cc/php::%php-is-double 4.2 t)
      (cl-cc/php::%php-is-real 4.2 t)
      (cl-cc/php::%php-is-string "hi" t)
      (cl-cc/php::%php-is-string 42 nil)
      (cl-cc/php::%php-is-bool t t)
      (cl-cc/php::%php-is-bool nil t)
      (cl-cc/php::%php-is-bool 0 nil)
      (cl-cc/php::%php-is-array 42 nil)
      (cl-cc/php::%php-is-iterable 42 nil)
      (cl-cc/php::%php-is-scalar 42 t)
      (cl-cc/php::%php-is-scalar "x" t)
      (cl-cc/php::%php-is-scalar t t)
      (cl-cc/php::%php-is-numeric 42 t)
      (cl-cc/php::%php-is-numeric "1.5" t)
      (cl-cc/php::%php-is-numeric "1.5abc" nil)
      (cl-cc/php::%php-is-numeric "abc" nil)
      (cl-cc/php::%php-is-callable "strlen" t)
      (cl-cc/php::%php-is-callable "this-is-not-a-real-function" nil))
    "~A(~S) reports ~A"
    (predicate input expected)
    (expect (and (funcall predicate input) t) :to-be expected))
  (it-sequential
    "is_array and is_iterable accept a PHP array (hash-table)"
    (let ((array (cl-cc/php::%php-array)))
      (expect (cl-cc/php::%php-is-array array) :to-be-truthy)
      (expect (cl-cc/php::%php-is-iterable array) :to-be-truthy)))
  (it-sequential
    "is_object reports true only for something that is not a scalar/array/null"
    (expect (cl-cc/php::%php-is-object cl-cc/php::+php-null+) :to-be nil)
    (expect (cl-cc/php::%php-is-object 42) :to-be nil)
    (expect (cl-cc/php::%php-is-object "x") :to-be nil)
    (expect (cl-cc/php::%php-is-object (cl-cc/php::%php-array)) :to-be nil)))

(describe
  "PHP scalar conversions"
  (it-sequential-each
    (("42" 42)
      ("  42" 42)
      ("42abc" 42)
      ("abc" 0)
      (4.9 4)
      (t 1)
      (nil 0))
    "intval(~S) => ~A"
    (input expected)
    (expect (cl-cc/php::%php-intval input) :to-equal expected))
  (it-sequential
    "intval honors an explicit non-decimal base"
    (expect (cl-cc/php::%php-intval "0x1A" 16) :to-equal 26)
    (expect (cl-cc/php::%php-intval "1A" 16) :to-equal 26)
    (expect (cl-cc/php::%php-intval "077" 8) :to-equal 63)
    (expect (cl-cc/php::%php-intval "101" 2) :to-equal 5))
  (it-sequential
    "intval autodetects base 0 from a numeric-literal prefix"
    (expect (cl-cc/php::%php-intval "0x1A" 0) :to-equal 26)
    (expect (cl-cc/php::%php-intval "010" 0) :to-equal 8)
    (expect (cl-cc/php::%php-intval "10" 0) :to-equal 10))
  (it-sequential-each
    (("1.5" 1.5)
      ("1.5abc" 0.0)
      ("abc" 0.0)
      (42 42.0)
      (t 1.0)
      (nil 0.0))
    "floatval(~S) => ~A"
    (input expected)
    (expect (cl-cc/php::%php-floatval input) :to-equal expected))
  (it-sequential
    "strval stringifies like the general PHP stringify helper"
    (expect (cl-cc/php::%php-strval 42) :to-equal "42")
    (expect (cl-cc/php::%php-strval t) :to-equal "1")
    (expect (cl-cc/php::%php-strval "already") :to-equal "already"))
  (it-sequential
    "boolval follows PHP truthiness"
    (expect (cl-cc/php::%php-boolval 0) :to-be nil)
    (expect (cl-cc/php::%php-boolval "") :to-be nil)
    (expect (cl-cc/php::%php-boolval "0") :to-be nil)
    (expect (cl-cc/php::%php-boolval 1) :to-be-truthy)
    (expect (cl-cc/php::%php-boolval "0.0") :to-be-truthy)))

(describe
  "PHP is_numeric / %php-string-numeric-p / filter_var(FILTER_VALIDATE_FLOAT): PHP's own
numeric-string grammar, not Common Lisp's reader grammar"
  ;; %PHP-STRING-NUMERIC-P and %PHP-FILTER-FLOAT-VALUE both used to delegate straight to
  ;; READ-FROM-STRING, which accepts Common Lisp syntax PHP's own numeric-string grammar does
  ;; not: a ratio like "1/2" reads as the CL ratio 1/2 (a NUMBERP), and a double-float exponent
  ;; marker like "1.0d0" reads as a valid CL float literal — so both silently treated non-numeric
  ;; PHP strings as numeric. %PHP-NUMERIC-GRAMMAR-P now validates the string against PHP's actual
  ;; grammar first.
  (it-sequential-each
    (("1/2" nil)
      ("1.0d0" nil)
      ("0x1A" nil)
      ("3.14" t)
      ("1e5" t)
      ("-.5" t)
      ("007" t)
      ("+5" t)
      ("5." t)
      ("5.5.5" nil)
      ("1e" nil)
      ("" nil)
      ("   " nil)
      ("  42  " t))
    "is_numeric(~S) => ~A"
    (input expected)
    (expect (cl-cc/php::%php-is-numeric input) :to-be expected))
  (it-sequential
    "filter_var(..., FILTER_VALIDATE_FLOAT) rejects the same CL-reader-only syntax"
    (expect (cl-cc/php::%php-filter-var "1/2" 259) :to-be nil)
    (expect (cl-cc/php::%php-filter-var "1.0d0" 259) :to-be nil)
    (expect (cl-cc/php::%php-filter-var "3.14" 259) :to-equal 3.14)))
