;;;; runtime-builtins-io-test.lisp — src/runtime-builtins-io.lisp and the files carved out of it.
;;;;
;;;; Covers -io-ini.lisp (INI settings, error reporting, handler stacks), -io-locale.lisp, and
;;;; -io-autoload.lisp (SPL autoload, class_*) as well. Global-state builtins run under a
;;;; save/restore guard so the suite stays order-independent.

(in-package :cl-cc-php/test)

(describe
  "PHP system, locale, and misc I/O builtins"
  (it-sequential
    "getenv/putenv round-trips an environment variable and reports missing ones"
    (expect (cl-cc/php::%php-putenv "CL_CC_PHP_TEST_VAR=hello") :to-be-truthy)
    (expect (cl-cc/php::%php-getenv "CL_CC_PHP_TEST_VAR") :to-equal "hello")
    (expect (cl-cc/php::%php-getenv "CL_CC_PHP_MISSING_VAR_ZZZ") :to-be nil)
    (expect (cl-cc/php::%php-putenv "NO_EQUALS_SIGN") :to-be nil))
  (it-sequential
    "the fixed system-identity builtins return their documented constants"
    (expect (cl-cc/php::%php-php-uname) :to-equal "Darwin")
    (expect (cl-cc/php::%php-php-sapi-name) :to-equal "cli")
    (expect (cl-cc/php::%php-php-version) :to-equal "8.5.0")
    (expect (cl-cc/php::%php-php-int-size) :to-be 8)
    (expect (cl-cc/php::%php-php-int-max) :to-be 9223372036854775807)
    (expect (cl-cc/php::%php-php-int-min) :to-be -9223372036854775808)
    (expect (cl-cc/php::%php-php-float-max) :to-be most-positive-double-float)
    (expect (cl-cc/php::%php-php-float-epsilon) :to-be 2.220446049250313d-16))
  (it-sequential
    "memory_limit unit suffixes map to their byte multipliers"
    (expect (cl-cc/php::%php-memory-limit-unit-multiplier #\K) :to-be 1024)
    (expect (cl-cc/php::%php-memory-limit-unit-multiplier #\m) :to-be (expt 1024 2))
    (expect (cl-cc/php::%php-memory-limit-unit-multiplier #\G) :to-be (expt 1024 3))
    (expect (cl-cc/php::%php-memory-limit-unit-multiplier #\T) :to-be (expt 1024 4))
    (expect (cl-cc/php::%php-memory-limit-unit-multiplier #\?) :to-be 1))
  (it-sequential
    "parse-memory-limit handles -1, empty, suffixed, plain, and junk values"
    (expect
      (multiple-value-list (cl-cc/php::%php-parse-memory-limit "-1"))
      :to-equal
      (list nil t))
    (expect
      (multiple-value-list (cl-cc/php::%php-parse-memory-limit ""))
      :to-equal
      (list nil nil))
    (expect
      (multiple-value-list (cl-cc/php::%php-parse-memory-limit "128M"))
      :to-equal
      (list (* 128 (expt 1024 2)) nil))
    (expect
      (multiple-value-list (cl-cc/php::%php-parse-memory-limit "1024"))
      :to-equal
      (list 1024 nil))
    (expect
      (multiple-value-list (cl-cc/php::%php-parse-memory-limit "garbage"))
      :to-equal
      (list nil nil)))
  (it-sequential
    "memory-limit-exceeds-p compares byte sizes and honors the -1 unlimited sentinel"
    (expect (cl-cc/php::%php-memory-limit-exceeds-p "256M" "128M") :to-be-truthy)
    (expect (cl-cc/php::%php-memory-limit-exceeds-p "64M" "128M") :to-be nil)
    (expect (cl-cc/php::%php-memory-limit-exceeds-p "512M" "-1") :to-be nil)
    (expect (cl-cc/php::%php-memory-limit-exceeds-p "-1" "128M") :to-be-truthy))
  (it-sequential
    "ini_set stores a stringified value and returns the previous one; ini_get reads it back"
    (let ((key "clccphp.testkey"))
      (expect (cl-cc/php::%php-ini-get key) :to-be nil)
      (expect (cl-cc/php::%php-ini-set key "v1") :to-be nil)
      (expect (cl-cc/php::%php-ini-get key) :to-equal "v1")
      (expect (cl-cc/php::%php-ini-set key "v2") :to-equal "v1")
      (expect (cl-cc/php::%php-ini-get key) :to-equal "v2")
      (expect (cl-cc/php::%php-ini-set "max_memory_limit" "1M") :to-be nil)))
  (it-sequential
    "error_reporting returns the current level and installs a new one"
    (let ((saved cl-cc/php::*php-error-reporting-level*))
      (unwind-protect (progn
          (expect (cl-cc/php::%php-error-reporting) :to-be saved)
          (expect (cl-cc/php::%php-error-reporting 0) :to-be saved)
          (expect (cl-cc/php::%php-error-reporting) :to-be 0))
        (setf cl-cc/php::*php-error-reporting-level* saved))))
  (it-sequential
    "parse-integer-setting parses leading digits and yields nil on non-numeric text"
    (expect (cl-cc/php::%php-parse-integer-setting "42" 99) :to-be 42)
    (expect (cl-cc/php::%php-parse-integer-setting "12abc" 99) :to-be 12)
    (expect (cl-cc/php::%php-parse-integer-setting "abc" 99) :to-be nil))
  (it-sequential
    "set_error_handler installs a handler, get_error_handler returns it, restore pops it"
    (let ((saved cl-cc/php::*php-error-handler-stack*))
      (unwind-protect (let ((cb
              (lambda (&rest args)
                (declare (ignore args))
                t)))
          (setf cl-cc/php::*php-error-handler-stack* nil)
          (expect
            (cl-cc/php::%php-null-p (cl-cc/php::%php-get-error-handler))
            :to-be-truthy)
          (cl-cc/php::%php-set-error-handler cb)
          (expect (cl-cc/php::%php-get-error-handler) :to-be cb)
          (cl-cc/php::%php-restore-error-handler)
          (expect
            (cl-cc/php::%php-null-p (cl-cc/php::%php-get-error-handler))
            :to-be-truthy))
        (setf cl-cc/php::*php-error-handler-stack* saved))))
  (it-sequential
    "set_error_handler throws a PHP TypeError for a non-callable argument"
    (let ((saved cl-cc/php::*php-error-handler-stack*))
      (unwind-protect (expect
          (handler-case (progn
              (cl-cc/php::%php-set-error-handler 42)
              nil)
            (cl-cc/php:php-exception (e)
              e))
          :to-be-truthy)
        (setf cl-cc/php::*php-error-handler-stack* saved))))
  (it-sequential
    "set_exception_handler installs a handler and get_exception_handler reflects it"
    (let ((saved cl-cc/php::*php-exception-handler-stack*))
      (unwind-protect (let ((cb
              (lambda (&rest args)
                (declare (ignore args))
                nil)))
          (setf cl-cc/php::*php-exception-handler-stack* nil)
          (expect
            (cl-cc/php::%php-null-p (cl-cc/php::%php-get-exception-handler))
            :to-be-truthy)
          (cl-cc/php::%php-set-exception-handler cb)
          (expect (cl-cc/php::%php-get-exception-handler) :to-be cb)
          (cl-cc/php::%php-restore-exception-handler)
          (expect
            (cl-cc/php::%php-null-p (cl-cc/php::%php-get-exception-handler))
            :to-be-truthy))
        (setf cl-cc/php::*php-exception-handler-stack* saved))))
  (it-sequential
    "locale-normalized-id lowercases and strips encoding/modifier suffixes"
    (expect (cl-cc/php::%php-locale-normalized-id "en_US.UTF-8") :to-equal "en-us")
    (expect (cl-cc/php::%php-locale-normalized-id "de_DE@euro") :to-equal "de-de")
    (expect (cl-cc/php::%php-locale-normalized-id "fr") :to-equal "fr"))
  (it-sequential
    "locale-subtags splits a normalized id on hyphens"
    (expect
      (cl-cc/php::%php-locale-subtags "en-latn-us")
      :to-equal
      (list "en" "latn" "us"))
    (expect (cl-cc/php::%php-locale-subtags "fr") :to-equal (list "fr")))
  (it-sequential
    "addLikelySubtags/minimizeSubtags expand and contract locale ids"
    (expect (cl-cc/php::%php-locale-add-likely-subtags "en") :to-equal "en-Latn-US")
    (expect (cl-cc/php::%php-locale-add-likely-subtags "zz") :to-equal "zz-Latn-US")
    (expect (cl-cc/php::%php-locale-minimize-subtags "en_Latn_US") :to-equal "en"))
  (it-sequential
    "locale-is-right-to-left recognizes RTL languages and rejects LTR ones"
    (expect (cl-cc/php::%php-locale-is-right-to-left "ar") :to-be-truthy)
    (expect (cl-cc/php::%php-locale-is-right-to-left "fa") :to-be-truthy)
    (expect (cl-cc/php::%php-locale-is-right-to-left "en") :to-be nil))
  (it-sequential
    "parse_str decodes a query string into a PHP array, URL-decoding values"
    (let ((result (cl-cc/php::%php-parse-str "a=1&b=2")))
      (expect (cl-cc/php::%php-array-ref result "a") :to-equal "1")
      (expect (cl-cc/php::%php-array-ref result "b") :to-equal "2"))
    (let ((result (cl-cc/php::%php-parse-str "name=John%20Doe")))
      (expect (cl-cc/php::%php-array-ref result "name") :to-equal "John Doe")))
  (it-sequential
    "array_map with a null callback zips each key/value into a two-element row"
    (let ((arr (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set arr "x" 10)
      (let* ((result (cl-cc/php::%php-array-map-keys nil arr))
             (row (cl-cc/php::%php-array-ref result 0)))
        (expect (cl-cc/php::%php-array-ref row 0) :to-equal "x")
        (expect (cl-cc/php::%php-array-ref row 1) :to-be 10))))
  (it-sequential
    "list() packs its arguments into a numerically-keyed array"
    (let ((result (cl-cc/php::%php-list-assign "a" "b" "c")))
      (expect (cl-cc/php::%php-count result) :to-be 3)
      (expect (cl-cc/php::%php-array-ref result 0) :to-equal "a")
      (expect (cl-cc/php::%php-array-ref result 2) :to-equal "c")))
  (it-sequential
    "reset/current/end/next/prev/key report the array-pointer positions"
    (let ((arr (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set arr "first" 10)
      (cl-cc/php::%php-array-set arr "second" 20)
      (cl-cc/php::%php-array-set arr "third" 30)
      (expect (cl-cc/php::%php-reset arr) :to-be 10)
      (expect (cl-cc/php::%php-current arr) :to-be 10)
      (expect (cl-cc/php::%php-end arr) :to-be 30)
      (expect (cl-cc/php::%php-next arr) :to-be 20)
      (expect (cl-cc/php::%php-prev arr) :to-be 10)
      (expect (cl-cc/php::%php-key arr) :to-equal "first"))
    (let ((empty (cl-cc/php::%php-make-array)))
      (expect (cl-cc/php::%php-reset empty) :to-be nil)
      (expect (cl-cc/php::%php-next empty) :to-be nil)
      (expect (cl-cc/php::%php-key empty) :to-be nil)))
  (it-sequential
    "settype coerces a referenced value in place and rejects unknown type names"
    (let ((ref (cl-cc/php::%php-make-ref "123")))
      (expect (cl-cc/php::%php-settype ref "integer") :to-be-truthy)
      (expect (cl-cc/php::%php-deref ref) :to-be 123))
    (let ((ref (cl-cc/php::%php-make-ref 5)))
      (expect (cl-cc/php::%php-settype ref "string") :to-be-truthy)
      (expect (cl-cc/php::%php-deref ref) :to-equal "5"))
    (let ((ref (cl-cc/php::%php-make-ref "x")))
      (cl-cc/php::%php-settype ref "array")
      (expect (cl-cc/php::%php-array-ref (cl-cc/php::%php-deref ref) 0) :to-equal "x"))
    (let ((ref (cl-cc/php::%php-make-ref 1)))
      (expect (cl-cc/php::%php-settype ref "bogus-type") :to-be nil)))
  (it-sequential
    "the settype (array)/(object) cast shapers wrap scalars and null correctly"
    (expect
      (cl-cc/php::%php-array-ref (cl-cc/php::%php-settype-array-value "hi") 0)
      :to-equal
      "hi")
    (expect
      (cl-cc/php::%php-count
        (cl-cc/php::%php-settype-array-value cl-cc/php::+php-null+))
      :to-be
      0)
    (let ((obj (cl-cc/php::%php-settype-object-value 42)))
      (expect (cl-cc/php::%php-array-ref obj "__class__") :to-equal "stdClass")
      (expect (cl-cc/php::%php-array-ref obj "scalar") :to-be 42)))
  (it-sequential
    "spl_autoload_register/unregister/functions manage the autoload queue without duplicates"
    (let ((saved cl-cc/php::*php-spl-autoload-functions*))
      (unwind-protect (progn
          (setf cl-cc/php::*php-spl-autoload-functions* nil)
          (expect (cl-cc/php::%php-spl-autoload-register "my_loader") :to-be-truthy)
          (expect (cl-cc/php::%php-spl-autoload-register "my_loader") :to-be-truthy)
          (expect
            (cl-cc/php::%php-count (cl-cc/php::%php-spl-autoload-functions))
            :to-be
            1)
          (expect (cl-cc/php::%php-spl-autoload-unregister "my_loader") :to-be-truthy)
          (expect
            (cl-cc/php::%php-count (cl-cc/php::%php-spl-autoload-functions))
            :to-be
            0)
          (expect (cl-cc/php::%php-spl-autoload-unregister "my_loader") :to-be nil))
        (setf cl-cc/php::*php-spl-autoload-functions* saved))))
  (it-sequential
    "spl_autoload_register prepends when asked and validates its callback argument"
    (let ((saved cl-cc/php::*php-spl-autoload-functions*))
      (unwind-protect (progn
          (setf cl-cc/php::*php-spl-autoload-functions* nil)
          (cl-cc/php::%php-spl-autoload-register "a")
          (cl-cc/php::%php-spl-autoload-register "b" nil t)
          (expect
            (cl-cc/php::%php-array-values-list (cl-cc/php::%php-spl-autoload-functions))
            :to-equal
            (list "b" "a"))
          (expect (cl-cc/php::%php-spl-autoload-register 42 nil) :to-be nil)
          (expect
            (handler-case (progn
                (cl-cc/php::%php-spl-autoload-register 42 t)
                nil)
              (cl-cc/php:php-exception (e)
                e))
            :to-be-truthy))
        (setf cl-cc/php::*php-spl-autoload-functions* saved))))
  (it-sequential
    "spl-autoload-callback-valid-p accepts strings/functions but rejects numbers and empty arrays"
    (expect (cl-cc/php::%php-spl-autoload-callback-valid-p "name") :to-be-truthy)
    (expect
      (cl-cc/php::%php-spl-autoload-callback-valid-p
        (lambda ()
          nil))
      :to-be-truthy)
    (expect (cl-cc/php::%php-spl-autoload-callback-valid-p 42) :to-be nil)
    (expect
      (cl-cc/php::%php-spl-autoload-callback-valid-p (cl-cc/php::%php-make-array))
      :to-be
      nil))
  (it-sequential
    "lcg_value returns a float in the half-open unit interval"
    (let ((value (cl-cc/php::%php-lcg-value)))
      (expect (and (floatp value) (>= value 0) (< value 1)) :to-be-truthy)))
  (it-sequential
    "iterator_to_array/iterator_count pass a plain array straight through"
    (let ((arr (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set arr 0 "a")
      (cl-cc/php::%php-array-set arr 1 "b")
      (expect (cl-cc/php::%php-iterator-to-array arr) :to-be arr)
      (expect (cl-cc/php::%php-iterator-count arr) :to-be 2)))
  (it-sequential
    "class_parents/class_implements/class_uses return an empty array for an unknown class"
    (expect
      (cl-cc/php::%php-count (cl-cc/php::%php-class-parents "NoSuchClassXyz"))
      :to-be
      0)
    (expect
      (cl-cc/php::%php-count (cl-cc/php::%php-class-implements "NoSuchClassXyz"))
      :to-be
      0)
    (expect
      (cl-cc/php::%php-count (cl-cc/php::%php-class-uses "NoSuchClassXyz"))
      :to-be
      0))
  (it-sequential
    "path-string namestrings a pathname and stringifies everything else"
    (expect (cl-cc/php::%php-path-string "/a/b") :to-equal "/a/b")
    (expect (cl-cc/php::%php-path-string #p"/a/b") :to-equal "/a/b"))
  (it-sequential
    "sleep/usleep return PHP's documented values for a zero-length delay"
    (expect (cl-cc/php::%php-sleep 0) :to-be 0)
    (expect (cl-cc/php::%php-usleep 0) :to-be nil))
  (it-sequential
    "microtime(true) returns a float"
    (expect (floatp (cl-cc/php::%php-microtime-float)) :to-be-truthy)))
