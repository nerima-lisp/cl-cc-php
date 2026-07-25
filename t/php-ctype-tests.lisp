(in-package :cl-cc-php/test)

;;; Table-driven via cl-weave's IT-SEQUENTIAL-EACH: every ctype_* predicate
;;; shares the exact same (predicate input expected) shape, so one data table
;;; plus one body replaces ten near-identical IT-SEQUENTIAL blocks.

(describe "PHP ctype_* character classification"

(it-sequential-each
    ((cl-cc/php::%php-ctype-alpha "Hello" t)
     (cl-cc/php::%php-ctype-alpha "Hello1" nil)
     (cl-cc/php::%php-ctype-alpha "" nil)

     (cl-cc/php::%php-ctype-digit "12345" t)
     (cl-cc/php::%php-ctype-digit "123a5" nil)
     (cl-cc/php::%php-ctype-digit "" nil)

     (cl-cc/php::%php-ctype-alnum "abc123" t)
     (cl-cc/php::%php-ctype-alnum "abc 123" nil)
     (cl-cc/php::%php-ctype-alnum "" nil)

     (cl-cc/php::%php-ctype-space "   " t)
     (cl-cc/php::%php-ctype-space "a b" nil)
     (cl-cc/php::%php-ctype-space "" nil)

     (cl-cc/php::%php-ctype-upper "ABC" t)
     (cl-cc/php::%php-ctype-upper "ABc" nil)
     (cl-cc/php::%php-ctype-upper "" nil)

     (cl-cc/php::%php-ctype-lower "abc" t)
     (cl-cc/php::%php-ctype-lower "abC" nil)
     (cl-cc/php::%php-ctype-lower "" nil)

     (cl-cc/php::%php-ctype-punct "!@#" t)
     (cl-cc/php::%php-ctype-punct "a!" nil)
     (cl-cc/php::%php-ctype-punct "! !" nil)
     (cl-cc/php::%php-ctype-punct "" nil)

     (cl-cc/php::%php-ctype-graph "abc!123" t)
     (cl-cc/php::%php-ctype-graph "abc 123" nil)
     (cl-cc/php::%php-ctype-graph "" nil)

     (cl-cc/php::%php-ctype-print "abc 123" t)
     (cl-cc/php::%php-ctype-print "" nil)

     (cl-cc/php::%php-ctype-xdigit "1a2B3f" t)
     (cl-cc/php::%php-ctype-xdigit "1a2g" nil)
     (cl-cc/php::%php-ctype-xdigit "" nil))
    "~A(~S) reports ~A"
    (predicate input expected)
  (expect (and (funcall predicate input) t) :to-be expected))

  )
