;;;; runtime-constants-test.lisp — src/runtime-constants.lisp — predefined constant lookup.
;;;;
;;;; The predefined-constant tables are data, not logic, so the useful test is not "spot-check a
;;;; handful of names" but "every registered entry round-trips through its own lookup function" —
;;;; that catches a typo'd or duplicate key the same way a checksum catches a bit flip, and it
;;;; exercises %php-lookup-constant/%php-lookup-dynamic-constant/%php-predefined-class-constant
;;;; far more thoroughly than the handful of constant names any individual e2e test happens to
;;;; reference by name.

(in-package :cl-cc-php/test)

(describe "PHP predefined constants"

(it-sequential "every entry in *php-predefined-constants* round-trips through %php-lookup-constant"
  (maphash
    (lambda (name expected)
      (multiple-value-bind (value found) (cl-cc/php::%php-lookup-constant name)
        (expect found :to-be-truthy)
        (expect value :to-equal expected)))
    cl-cc/php::*php-predefined-constants*))

(it-sequential "%php-lookup-constant resolves a namespace-qualified name to its global value"
  (multiple-value-bind (value found) (cl-cc/php::%php-lookup-constant "App\\Sub\\PHP_EOL")
    (expect found :to-be-truthy)
    (expect value :to-equal (string #\Newline))))

(it-sequential "%php-lookup-constant reports NIL/NIL for an unregistered name"
  (multiple-value-bind (value found) (cl-cc/php::%php-lookup-constant "NOT_A_REAL_CONSTANT")
    (expect found :to-be nil)
    (expect value :to-be nil)))

(it-sequential-each
    (("STDIN") ("STDOUT") ("STDERR"))
    "%php-lookup-dynamic-constant(~S) resolves to its zero-arg runtime helper symbol"
    (name)
  (multiple-value-bind (helper found) (cl-cc/php::%php-lookup-dynamic-constant name)
    (expect found :to-be-truthy)
    (expect (fboundp helper) :to-be-truthy)))

(it-sequential "%php-lookup-dynamic-constant resolves a namespace-qualified dynamic name"
  (multiple-value-bind (helper found) (cl-cc/php::%php-lookup-dynamic-constant "App\\STDOUT")
    (expect found :to-be-truthy)
    (expect helper :to-be 'cl-cc/php::%php-stdout)))

(it-sequential "%php-lookup-dynamic-constant reports NIL/NIL for an unregistered name"
  (multiple-value-bind (helper found) (cl-cc/php::%php-lookup-dynamic-constant "NOT_DYNAMIC")
    (expect found :to-be nil)
    (expect helper :to-be nil)))

(it-sequential
    "every registered predefined class constant round-trips through %php-predefined-class-constant"
  (maphash
    (lambda (key expected)
      (destructuring-bind (class-name . constant-name) key
        (expect
          (cl-cc/php:%php-predefined-class-constant class-name constant-name)
          :to-equal
          expected)))
    cl-cc/php::*php-predefined-class-constants*))

(it-sequential "%php-predefined-class-constant signals an error for an unregistered pair"
  (signals error (cl-cc/php:%php-predefined-class-constant "NoSuchClass" "NO_SUCH_CONST")))

  )
