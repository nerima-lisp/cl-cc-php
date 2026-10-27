;;;; runtime-builtins-math-test.lisp — src/runtime-builtins-math.lisp — rounding, extrema, base
;;;; conversion.

(in-package :cl-cc/php/stdlib/test)

(describe "PHP math: rounding and basic arithmetic"

(it-sequential "abs returns the absolute value"
  (expect (cl-cc/php/stdlib:%php-abs -3) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-abs 3) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-abs -3.5) :to-equal 3.5))

(it-sequential "ceil/floor round toward +/- infinity"
  (expect (cl-cc/php/stdlib:%php-ceil 2.1) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-ceil -2.1) :to-equal -2)
  (expect (cl-cc/php/stdlib:%php-floor 2.9) :to-equal 2)
  (expect (cl-cc/php/stdlib:%php-floor -2.1) :to-equal -3))

(it-sequential "round rounds halves away from zero, unlike CL's banker's rounding"
  (expect (cl-cc/php/stdlib:%php-round 2.5) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-round -2.5) :to-equal -3)
  (expect (cl-cc/php/stdlib:%php-round 3.5) :to-equal 4))

(it-sequential "round honors a decimal-place precision argument"
  ;; %php-round returns an exact rational (157/50), not a double-float
  ;; approximation of 3.14, so comparing against the 3.14 literal with = would
  ;; fail on the literal's own float imprecision rather than a real mismatch.
  (expect (cl-cc/php/stdlib:%php-round 3.14159 2) :to-equal 157/50))

(it-sequential "sqrt coerces to double-float for full precision"
  (expect (typep (cl-cc/php/stdlib:%php-sqrt 2) 'double-float) :to-be-truthy)
  (expect (cl-cc/php/stdlib:%php-sqrt 4) :to-equal 2.0d0))

(it-sequential "pow raises base to exponent"
  (expect (cl-cc/php/stdlib:%php-pow 2 10) :to-equal 1024)
  (expect (cl-cc/php/stdlib:%php-pow 2 0) :to-equal 1))

(it-sequential "intdiv truncates toward zero"
  (expect (cl-cc/php/stdlib:%php-intdiv 7 2) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-intdiv -7 2) :to-equal -3))

(it-sequential "intdiv signals a php-exception tagged division-by-zero-error for a zero divisor"
  ;; %php-throw always signals CL-CC/PHP:PHP-EXCEPTION; the PHP-level class name
  ;; ("division-by-zero-error") is metadata in its CLASS-NAME slot, not a
  ;; distinct condition class, so SIGNALS (which expects a condition class
  ;; designator) cannot target it directly.
  (handler-case (progn (cl-cc/php/stdlib:%php-intdiv 7 0) (expect nil :to-be-truthy))
    (cl-cc/php:php-exception (e)
      (expect (cl-cc/php/errors:%php-exception-class e) :to-equal 'cl-cc/php/stdlib:division-by-zero-error))))

(it-sequential "fdiv returns IEEE-style +/-infinity approximations instead of erroring on zero"
  (expect (cl-cc/php/stdlib:%php-fdiv 6 3) :to-equal 2.0d0)
  (expect (cl-cc/php/stdlib:%php-fdiv 1 0) :to-equal most-positive-double-float)
  (expect (cl-cc/php/stdlib:%php-fdiv -1 0) :to-equal most-negative-double-float))

  )

(describe "PHP math: max/min"

(it-sequential "max/min compare a plain argument list"
  (expect (cl-cc/php/stdlib:%php-max 1 3 2) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-min 1 3 2) :to-equal 1))

(it-sequential "max/min accept a single PHP array argument and compare its elements"
  (let ((array (cl-cc/php/arrays:%php-list-to-array (list 5 1 9 3))))
    (expect (cl-cc/php/stdlib:%php-max array) :to-equal 9)
    (expect (cl-cc/php/stdlib:%php-min array) :to-equal 1)))

(it-sequential "max/min of a single non-array argument return that argument"
  (expect (cl-cc/php/stdlib:%php-max 42) :to-equal 42)
  (expect (cl-cc/php/stdlib:%php-min 42) :to-equal 42))

  )

(describe "PHP math: base conversion"

(it-sequential-each
    ((10 "1010")
     (255 "11111111")
     (0 "0"))
    "decbin(~S) => ~S"
    (n expected)
  (expect (cl-cc/php/stdlib:%php-decbin n) :to-equal expected))

(it-sequential-each
    ((8 "10")
     (511 "777"))
    "decoct(~S) => ~S"
    (n expected)
  (expect (cl-cc/php/stdlib:%php-decoct n) :to-equal expected))

(it-sequential-each
    ((255 "ff")
     (26 "1a"))
    "dechex(~S) => ~S"
    (n expected)
  (expect (cl-cc/php/stdlib:%php-dechex n) :to-equal expected))

(it-sequential-each
    (("1010" 10)
     ("11111111" 255))
    "bindec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php/stdlib:%php-bindec s) :to-equal expected))

(it-sequential-each
    (("10" 8)
     ("777" 511))
    "octdec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php/stdlib:%php-octdec s) :to-equal expected))

(it-sequential-each
    (("ff" 255)
     ("1a" 26)
     ("FF" 255))
    "hexdec(~S) => ~S"
    (s expected)
  (expect (cl-cc/php/stdlib:%php-hexdec s) :to-equal expected))

(it-sequential "base_convert converts between arbitrary radixes"
  (expect (cl-cc/php/stdlib:%php-base-convert "ff" 16 10) :to-equal "255")
  (expect (cl-cc/php/stdlib:%php-base-convert "255" 10 16) :to-equal "ff"))

  )

(describe "PHP math: trigonometry, logarithms, angle conversion, finiteness"

(it-sequential "sin/cos/tan match Common Lisp's own trig functions"
  ;; %php-sin/cos/tan coerce their argument to double-float (PHP floats are
  ;; doubles); comparing against (sin 0) etc. would compare against CL's
  ;; single-float result for an exact-integer argument instead.
  (expect (cl-cc/php/stdlib:%php-sin 0) :to-equal (sin 0.0d0))
  (expect (cl-cc/php/stdlib:%php-cos 0) :to-equal (cos 0.0d0))
  (expect (cl-cc/php/stdlib:%php-tan 0) :to-equal (tan 0.0d0)))

(it-sequential "log with no base is natural log; with a base it's log-base-N"
  ;; (exp 1) is single-float precision; %php-log widens its double-float
  ;; coercion of that already-imprecise value, so log(exp(1)) misses 1.0d0.
  ;; (exp 1.0d0) keeps the whole round-trip in double precision.
  (expect (= (cl-cc/php/stdlib:%php-log (exp 1.0d0)) 1.0d0) :to-be-truthy)
  (expect (cl-cc/php/stdlib:%php-log 8 2) :to-equal 3.0d0)
  (expect (cl-cc/php/stdlib:%php-log 100 10) :to-equal 2.0d0))

(it-sequential "log10/log2 are the base-10/base-2 special cases"
  ;; %php-log10/%php-log2 special-case an exact integer power of their base
  ;; (see %php-log-exact-power) and return the exact integer exponent rather
  ;; than a double-float, so 1000 and 8 come back as 3, not 3.0d0.
  (expect (cl-cc/php/stdlib:%php-log10 1000) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-log2 8) :to-equal 3))

(it-sequential "fmod returns the floating-point remainder"
  (expect (cl-cc/php/stdlib:%php-fmod 7.5 2) :to-equal 1.5d0))

(it-sequential "deg2rad/rad2deg convert between degrees and radians"
  (expect (= (cl-cc/php/stdlib:%php-deg2rad 180) pi) :to-be-truthy)
  (expect (= (cl-cc/php/stdlib:%php-rad2deg pi) 180.0d0) :to-be-truthy))

(it-sequential "hypot returns the Euclidean distance"
  (expect (cl-cc/php/stdlib:%php-hypot 3 4) :to-equal 5.0d0))

(it-sequential "is_finite/is_infinite/is_nan classify special float values"
  (expect (cl-cc/php/stdlib:%php-is-finite 1.0d0) :to-be-truthy)
  ;; MOST-POSITIVE-DOUBLE-FLOAT is this runtime's stand-in for PHP's INF (see
  ;; runtime-constants.lisp's "INF" definition and %php-fdiv): it is treated
  ;; as infinite everywhere, consistently, not just here.
  (expect (cl-cc/php/stdlib:%php-is-finite most-positive-double-float) :to-be nil)
  (expect (cl-cc/php/stdlib:%php-is-nan 1.0d0) :to-be nil)
  (expect (cl-cc/php/stdlib:%php-is-infinite most-positive-double-float) :to-be-truthy)
  (expect (cl-cc/php/stdlib:%php-is-infinite 1.0d0) :to-be nil))

(it-sequential "pi and atan2"
  (expect (cl-cc/php/stdlib:%php-pi) :to-equal pi)
  (expect (cl-cc/php/stdlib:%php-atan2 0 1) :to-equal 0.0d0)
  (expect (= (cl-cc/php/stdlib:%php-atan2 1 0) (/ pi 2)) :to-be-truthy))

  )

(describe "PHP math: bcmath (arbitrary precision, as decimal strings)"

(it-sequential "bcadd/bcsub/bcmul honor SCALE decimal places, defaulting to 0"
  (expect (cl-cc/php/stdlib:%php-bcadd "2" "3") :to-equal "5.")
  (expect (cl-cc/php/stdlib:%php-bcadd "2" "3" 2) :to-equal "5.00")
  (expect (cl-cc/php/stdlib:%php-bcsub "5" "3" 2) :to-equal "2.00")
  (expect (cl-cc/php/stdlib:%php-bcmul "3" "3" 4) :to-equal "9.0000"))

(it-sequential "bcadd/bcsub/bcmul accept numeric (non-string) operands too"
  (expect (cl-cc/php/stdlib:%php-bcadd 2 3) :to-equal "5."))

(it-sequential "bcdiv divides to SCALE decimal places and signals on division by zero"
  (expect (cl-cc/php/stdlib:%php-bcdiv "10" "3" 2) :to-equal "3.33")
  (signals error (cl-cc/php/stdlib:%php-bcdiv "1" "0")))

(it-sequential "bcmod is integer modulo and signals on division by zero"
  (expect (cl-cc/php/stdlib:%php-bcmod "10" "3") :to-equal "1")
  (signals error (cl-cc/php/stdlib:%php-bcmod "1" "0")))

(it-sequential "bccomp returns -1, 0, or 1"
  (expect (cl-cc/php/stdlib:%php-bccomp "2" "3") :to-be -1)
  (expect (cl-cc/php/stdlib:%php-bccomp "3" "2") :to-be 1)
  (expect (cl-cc/php/stdlib:%php-bccomp "3" "3") :to-be 0))

(it-sequential "bcscale is a no-op that returns true (no global scale state to set)"
  (expect (cl-cc/php/stdlib:%php-bcscale 4) :to-be-truthy))

(it-sequential "bcsqrt computes to SCALE decimal places"
  (expect (cl-cc/php/stdlib:%php-bcsqrt "9" 2) :to-equal "3.00"))

(it-sequential "bcpow raises to a power"
  (expect (cl-cc/php/stdlib:%php-bcpow "2" "10") :to-equal "1024."))

  )

(describe "PHP math: gmp_* (arbitrary precision, mapped directly to CL bignums)"

(it-sequential-each
    ((42 42) ("42" 42) ("42abc" 42) ("abc" 0) (4.9d0 4))
    "%php-gmp-num(~S) => ~S"
    (input expected)
  (expect (cl-cc/php/stdlib:%php-gmp-num input) :to-equal expected))

(it-sequential "gmp_init parses a plain number or a string in an explicit base"
  (expect (cl-cc/php/stdlib:%php-gmp-init 42) :to-equal 42)
  (expect (cl-cc/php/stdlib:%php-gmp-init "42") :to-equal 42)
  (expect (cl-cc/php/stdlib:%php-gmp-init "ff" 16) :to-equal 255))

(it-sequential "gmp_add/sub/mul/gcd operate on GMP-coerced operands"
  (expect (cl-cc/php/stdlib:%php-gmp-add 2 3) :to-equal 5)
  (expect (cl-cc/php/stdlib:%php-gmp-sub 5 3) :to-equal 2)
  (expect (cl-cc/php/stdlib:%php-gmp-mul 4 5) :to-equal 20)
  (expect (cl-cc/php/stdlib:%php-gmp-gcd 12 18) :to-equal 6))

(it-sequential "gmp_div_q truncates toward zero and returns 0 for division by zero"
  (expect (cl-cc/php/stdlib:%php-gmp-div-q 7 2) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-gmp-div-q 7 0) :to-equal 0))

(it-sequential "gmp_mod returns 0 for division by zero instead of signaling"
  (expect (cl-cc/php/stdlib:%php-gmp-mod 7 3) :to-equal 1)
  (expect (cl-cc/php/stdlib:%php-gmp-mod 7 0) :to-equal 0))

(it-sequential "gmp_pow/abs/neg/cmp"
  (expect (cl-cc/php/stdlib:%php-gmp-pow 2 10) :to-equal 1024)
  (expect (cl-cc/php/stdlib:%php-gmp-abs -5) :to-equal 5)
  (expect (cl-cc/php/stdlib:%php-gmp-neg 5) :to-equal -5)
  (expect (cl-cc/php/stdlib:%php-gmp-cmp 2 3) :to-be -1)
  (expect (cl-cc/php/stdlib:%php-gmp-cmp 3 2) :to-be 1)
  (expect (cl-cc/php/stdlib:%php-gmp-cmp 3 3) :to-be 0))

(it-sequential "gmp_intval/strval/sqrt/fact"
  (expect (cl-cc/php/stdlib:%php-gmp-intval "42") :to-equal 42)
  (expect (cl-cc/php/stdlib:%php-gmp-strval 255 16) :to-equal "FF")
  (expect (cl-cc/php/stdlib:%php-gmp-sqrt 9) :to-equal 3)
  (expect (cl-cc/php/stdlib:%php-gmp-fact 5) :to-equal 120)
  (expect (cl-cc/php/stdlib:%php-gmp-fact 0) :to-equal 1))

  )

(describe "PHP math: rand/srand and the CSPRNG family"

(it-sequential "rand/mt_rand with no bounds return a non-negative fixnum"
  (expect (>= (cl-cc/php/stdlib:%php-rand) 0) :to-be-truthy)
  (expect (>= (cl-cc/php/stdlib:%php-mt-rand) 0) :to-be-truthy))

(it-sequential "rand/mt_rand with bounds stay within [min, max] inclusive"
  (dotimes (_ 20)
    (let ((r (cl-cc/php/stdlib:%php-rand 5 10)))
      (expect (<= 5 r 10) :to-be-truthy))))

(it-sequential "srand/mt_srand accept an optional seed without error"
  ;; With no seed, %PHP-SRAND has nothing to do and returns NIL. With a seed,
  ;; it replaces *RANDOM-STATE* and returns that new state object (not NIL) —
  ;; the portable CL random-state API has no PHP-compatible seeded stream, so
  ;; a provided seed only selects a fresh implementation state.
  (expect (cl-cc/php/stdlib:%php-srand) :to-be nil)
  (expect (cl-cc/php/stdlib:%php-srand 42) :to-be-truthy)
  (expect (cl-cc/php/stdlib:%php-mt-srand 42) :to-be-truthy))

(it-sequential "random_int stays within [min, max] and signals when min > max"
  (dotimes (_ 20)
    (let ((r (cl-cc/php/stdlib:%php-random-int 5 10)))
      (expect (<= 5 r 10) :to-be-truthy)))
  (signals error (cl-cc/php/stdlib:%php-random-int 10 5)))

(it-sequential "random_bytes returns a string of exactly LENGTH characters"
  (expect (length (cl-cc/php/stdlib:%php-random-bytes 16)) :to-be 16)
  (expect (stringp (cl-cc/php/stdlib:%php-random-bytes 8)) :to-be-truthy))

  )
