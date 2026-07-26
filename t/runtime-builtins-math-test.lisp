;;;; runtime-builtins-math-test.lisp — src/runtime-builtins-math.lisp — rounding, extrema, base
;;;; conversion.
;;;;
;;;; NOTE: this file is not listed in cl-cc-php.asd, so it is not currently loaded or run. See the
;;;; CHANGELOG.

(in-package :cl-cc-php/test)

(describe "PHP math: rounding and basic arithmetic"

(it-sequential "abs returns the absolute value"
  (expect (cl-cc/php::%php-abs -3) :to-equal 3)
  (expect (cl-cc/php::%php-abs 3) :to-equal 3)
  (expect (cl-cc/php::%php-abs -3.5) :to-equal 3.5))

(it-sequential "ceil/floor round toward +/- infinity"
  (expect (cl-cc/php::%php-ceil 2.1) :to-equal 3)
  (expect (cl-cc/php::%php-ceil -2.1) :to-equal -2)
  (expect (cl-cc/php::%php-floor 2.9) :to-equal 2)
  (expect (cl-cc/php::%php-floor -2.1) :to-equal -3))

(it-sequential "round rounds halves away from zero, unlike CL's banker's rounding"
  (expect (cl-cc/php::%php-round 2.5) :to-equal 3)
  (expect (cl-cc/php::%php-round -2.5) :to-equal -3)
  (expect (cl-cc/php::%php-round 3.5) :to-equal 4))

(it-sequential "round honors a decimal-place precision argument"
  (expect (cl-cc/php::%php-round 3.14159 2) :to-equal 157/50)
  (expect (= (cl-cc/php::%php-round 3.14159 2) 3.14) :to-be-truthy))

(it-sequential "sqrt coerces to double-float for full precision"
  (expect (typep (cl-cc/php::%php-sqrt 2) 'double-float) :to-be-truthy)
  (expect (cl-cc/php::%php-sqrt 4) :to-equal 2.0d0))

(it-sequential "pow raises base to exponent"
  (expect (cl-cc/php::%php-pow 2 10) :to-equal 1024)
  (expect (cl-cc/php::%php-pow 2 0) :to-equal 1))

(it-sequential "intdiv truncates toward zero"
  (expect (cl-cc/php::%php-intdiv 7 2) :to-equal 3)
  (expect (cl-cc/php::%php-intdiv -7 2) :to-equal -3))

(it-sequential "intdiv signals division-by-zero-error for a zero divisor"
  (signals cl-cc/php::division-by-zero-error (cl-cc/php::%php-intdiv 7 0)))

(it-sequential "fdiv returns IEEE-style +/-infinity approximations instead of erroring on zero"
  (expect (cl-cc/php::%php-fdiv 6 3) :to-equal 2.0d0)
  (expect (cl-cc/php::%php-fdiv 1 0) :to-equal most-positive-double-float)
  (expect (cl-cc/php::%php-fdiv -1 0) :to-equal most-negative-double-float))

  )

(describe "PHP math: max/min"

(it-sequential "max/min compare a plain argument list"
  (expect (cl-cc/php::%php-max 1 3 2) :to-equal 3)
  (expect (cl-cc/php::%php-min 1 3 2) :to-equal 1))

(it-sequential "max/min accept a single PHP array argument and compare its elements"
  (let ((array (cl-cc/php::%php-list-to-array (list 5 1 9 3))))
    (expect (cl-cc/php::%php-max array) :to-equal 9)
    (expect (cl-cc/php::%php-min array) :to-equal 1)))

(it-sequential "max/min of a single non-array argument return that argument"
  (expect (cl-cc/php::%php-max 42) :to-equal 42)
  (expect (cl-cc/php::%php-min 42) :to-equal 42))

  )

(describe "PHP math: base conversion"

(it-sequential-each
    ((10 "1010")
     (255 "11111111")
     (0 "0"))
    "decbin(~S) => ~S"
    (n expected)
  (expect (cl-cc/php::%php-decbin n) :to-equal expected))

(it-sequential-each
    ((8 "10")
     (511 "777"))
    "decoct(~S) => ~S"
    (n expected)
  (expect (cl-cc/php::%php-decoct n) :to-equal expected))

(it-sequential-each
    ((255 "ff")
     (26 "1a"))
    "dechex(~S) => ~S"
    (n expected)
  (expect (cl-cc/php::%php-dechex n) :to-equal expected))

(it-sequential-each
    (("1010" 10)
     ("11111111" 255))
    "bindec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php::%php-bindec s) :to-equal expected))

(it-sequential-each
    (("10" 8)
     ("777" 511))
    "octdec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php::%php-octdec s) :to-equal expected))

(it-sequential-each
    (("ff" 255)
     ("1a" 26)
     ("FF" 255))
    "hexdec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php::%php-hexdec s) :to-equal expected))

(it-sequential "base_convert converts between arbitrary radixes"
  (expect (cl-cc/php::%php-base-convert "ff" 16 10) :to-equal "255")
  (expect (cl-cc/php::%php-base-convert "255" 10 16) :to-equal "ff"))

  )

(describe "PHP math: trigonometry, logarithms, angle conversion, finiteness"

(it-sequential "sin/cos/tan match Common Lisp's own trig functions"
  (expect (cl-cc/php::%php-sin 0) :to-equal (sin 0))
  (expect (cl-cc/php::%php-cos 0) :to-equal (cos 0))
  (expect (cl-cc/php::%php-tan 0) :to-equal (tan 0)))

(it-sequential "log with no base is natural log; with a base it's log-base-N"
  (expect (= (cl-cc/php::%php-log (exp 1)) 1.0d0) :to-be-truthy)
  (expect (cl-cc/php::%php-log 8 2) :to-equal 3.0d0)
  (expect (cl-cc/php::%php-log 100 10) :to-equal 2.0d0))

(it-sequential "log10/log2 are the base-10/base-2 special cases"
  (expect (cl-cc/php::%php-log10 1000) :to-equal 3.0d0)
  (expect (cl-cc/php::%php-log2 8) :to-equal 3.0d0))

(it-sequential "fmod returns the floating-point remainder"
  (expect (cl-cc/php::%php-fmod 7.5 2) :to-equal 1.5d0))

(it-sequential "deg2rad/rad2deg convert between degrees and radians"
  (expect (= (cl-cc/php::%php-deg2rad 180) pi) :to-be-truthy)
  (expect (= (cl-cc/php::%php-rad2deg pi) 180.0d0) :to-be-truthy))

(it-sequential "hypot returns the Euclidean distance"
  (expect (cl-cc/php::%php-hypot 3 4) :to-equal 5.0d0))

(it-sequential "is_finite/is_infinite/is_nan classify special float values"
  (expect (cl-cc/php::%php-is-finite 1.0d0) :to-be-truthy)
  (expect (cl-cc/php::%php-is-finite most-positive-double-float) :to-be-truthy)
  (expect (cl-cc/php::%php-is-nan 1.0d0) :to-be nil))

  )
