;;;; runtime-builtins-string-ctype-test.lisp — src/runtime-builtins-string-ctype.lisp — the ctype_*
;;;; predicates.

(in-package :cl-cc/php/stdlib/test)

;;; Table-driven via cl-weave's IT-SEQUENTIAL-EACH: every ctype_* predicate
;;; shares the exact same (predicate input expected) shape, so one data table
;;; plus one body replaces ten near-identical IT-SEQUENTIAL blocks.

(describe "PHP ctype_* character classification"

(it-sequential-each
    ((cl-cc/php/stdlib::%php-ctype-alpha "Hello" t)
     (cl-cc/php/stdlib::%php-ctype-alpha "Hello1" nil)
     (cl-cc/php/stdlib::%php-ctype-alpha "" nil)

     (cl-cc/php/stdlib::%php-ctype-digit "12345" t)
     (cl-cc/php/stdlib::%php-ctype-digit "123a5" nil)
     (cl-cc/php/stdlib::%php-ctype-digit "" nil)

     (cl-cc/php/stdlib::%php-ctype-alnum "abc123" t)
     (cl-cc/php/stdlib::%php-ctype-alnum "abc 123" nil)
     (cl-cc/php/stdlib::%php-ctype-alnum "" nil)

     (cl-cc/php/stdlib::%php-ctype-space "   " t)
     (cl-cc/php/stdlib::%php-ctype-space "a b" nil)
     (cl-cc/php/stdlib::%php-ctype-space "" nil)

     (cl-cc/php/stdlib::%php-ctype-upper "ABC" t)
     (cl-cc/php/stdlib::%php-ctype-upper "ABc" nil)
     (cl-cc/php/stdlib::%php-ctype-upper "" nil)

     (cl-cc/php/stdlib::%php-ctype-lower "abc" t)
     (cl-cc/php/stdlib::%php-ctype-lower "abC" nil)
     (cl-cc/php/stdlib::%php-ctype-lower "" nil)

     (cl-cc/php/stdlib::%php-ctype-punct "!@#" t)
     (cl-cc/php/stdlib::%php-ctype-punct "a!" nil)
     (cl-cc/php/stdlib::%php-ctype-punct "! !" nil)
     (cl-cc/php/stdlib::%php-ctype-punct "" nil)

     (cl-cc/php/stdlib::%php-ctype-graph "abc!123" t)
     (cl-cc/php/stdlib::%php-ctype-graph "abc 123" nil)
     (cl-cc/php/stdlib::%php-ctype-graph "" nil)

     (cl-cc/php/stdlib::%php-ctype-print "abc 123" t)
     (cl-cc/php/stdlib::%php-ctype-print "" nil)

     (cl-cc/php/stdlib::%php-ctype-xdigit "1a2B3f" t)
     (cl-cc/php/stdlib::%php-ctype-xdigit "1a2g" nil)
     (cl-cc/php/stdlib::%php-ctype-xdigit "" nil))
    "~A(~S) reports ~A"
    (predicate input expected)
  (expect (and (funcall predicate input) t) :to-be expected))

  )
