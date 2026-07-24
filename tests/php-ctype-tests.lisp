(in-package :cl-cc-php/test)

(describe
  "PHP ctype_* character classification"
  (it-sequential
    "ctype_alpha accepts only non-empty alphabetic strings"
    (expect (cl-cc/php::%php-ctype-alpha "Hello") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-alpha "Hello1") :to-be nil)
    (expect (cl-cc/php::%php-ctype-alpha "") :to-be nil))
  (it-sequential
    "ctype_digit accepts only non-empty decimal-digit strings"
    (expect (cl-cc/php::%php-ctype-digit "12345") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-digit "123a5") :to-be nil)
    (expect (cl-cc/php::%php-ctype-digit "") :to-be nil))
  (it-sequential
    "ctype_alnum accepts only non-empty alphanumeric strings"
    (expect (cl-cc/php::%php-ctype-alnum "abc123") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-alnum "abc 123") :to-be nil))
  (it-sequential
    "ctype_space accepts only non-empty whitespace strings"
    (expect
      (cl-cc/php::%php-ctype-space (format nil " ~C~C" #\Tab #\Newline))
      :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-space "a b") :to-be nil))
  (it-sequential
    "ctype_upper accepts only non-empty all-uppercase strings"
    (expect (cl-cc/php::%php-ctype-upper "ABC") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-upper "ABc") :to-be nil))
  (it-sequential
    "ctype_lower accepts only non-empty all-lowercase strings"
    (expect (cl-cc/php::%php-ctype-lower "abc") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-lower "abC") :to-be nil))
  (it-sequential
    "ctype_punct accepts only non-empty visible-non-alphanumeric strings"
    (expect (cl-cc/php::%php-ctype-punct "!@#") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-punct "a!") :to-be nil)
    (expect (cl-cc/php::%php-ctype-punct "! !") :to-be nil))
  (it-sequential
    "ctype_graph accepts only non-empty visible (non-space) strings"
    (expect (cl-cc/php::%php-ctype-graph "abc!123") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-graph "abc 123") :to-be nil))
  (it-sequential
    "ctype_print accepts only non-empty printable strings, space included"
    (expect (cl-cc/php::%php-ctype-print "abc 123") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-print (format nil "abc~C123" #\Tab)) :to-be nil))
  (it-sequential
    "ctype_xdigit accepts only non-empty hexadecimal-digit strings"
    (expect (cl-cc/php::%php-ctype-xdigit "1a2B3f") :to-be-truthy)
    (expect (cl-cc/php::%php-ctype-xdigit "1a2g") :to-be nil))
  (it-sequential
    "every ctype_* predicate rejects the empty string"
    (expect (cl-cc/php::%php-ctype-alpha "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-digit "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-alnum "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-space "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-upper "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-lower "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-punct "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-graph "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-print "") :to-be nil)
    (expect (cl-cc/php::%php-ctype-xdigit "") :to-be nil)))
