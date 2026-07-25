(in-package :cl-cc-php/test)

;;; Unit tests for runtime-builtins-string-core.lisp: the foundational PHP
;;; string builtins (str_replace, substr, trim family, explode/implode,
;;; strpos family, str_contains/starts_with/ends_with, strrev, str_repeat).

(describe "PHP core string builtins"

(it-sequential-each
    (("hello world" "world" "PHP" "hello PHP")
     ("aaa" "a" "b" "bbb")
     ("no match" "xyz" "!" "no match")
     ("" "x" "y" ""))
    "str_replace(subject=~S, search=~S, replace=~S) => ~S"
    (subject search replace expected)
  (expect (cl-cc/php::%php-str-replace search replace subject) :to-equal expected))

(it-sequential "str_replace treats an empty search string as a no-op"
  (expect (cl-cc/php::%php-str-replace "" "x" "abc") :to-equal "abc"))

(it-sequential "str_ireplace matches case-insensitively"
  (expect (cl-cc/php::%php-str-ireplace "WORLD" "PHP" "hello world") :to-equal "hello PHP")
  (expect (cl-cc/php::%php-str-ireplace "world" "PHP" "hello WORLD") :to-equal "hello PHP"))

(it-sequential-each
    (("abcdef" 1 3 "bcd")
     ("abcdef" -2 nil "ef")
     ("abcdef" 0 nil "abcdef")
     ("abcdef" 10 nil "")
     ("abcdef" 1 -1 "bcde")
     ("abcdef" -4 2 "cd"))
    "substr(~S, ~S, ~S) => ~S"
    (string start length expected)
  (expect (cl-cc/php::%php-substr string start length) :to-equal expected))

(it-sequential "trim/ltrim/rtrim strip default whitespace"
  (expect (cl-cc/php::%php-trim "  x  ") :to-equal "x")
  (expect (cl-cc/php::%php-ltrim "  x  ") :to-equal "x  ")
  (expect (cl-cc/php::%php-rtrim "  x  ") :to-equal "  x"))

(it-sequential "trim accepts a custom character set"
  (expect (cl-cc/php::%php-trim "--x--" "-") :to-equal "x")
  (expect (cl-cc/php::%php-ltrim "--x--" "-") :to-equal "x--")
  (expect (cl-cc/php::%php-rtrim "--x--" "-") :to-equal "--x"))

(it-sequential "explode splits on a literal delimiter"
  (expect (cl-cc/php::%php-array-values-list (cl-cc/php::%php-explode "," "a,b,c"))
          :to-equal (list "a" "b" "c")))

(it-sequential "explode with an empty delimiter returns the whole string as one piece"
  (expect (cl-cc/php::%php-array-values-list (cl-cc/php::%php-explode "" "abc"))
          :to-equal (list "abc")))

(it-sequential "explode with no delimiter match returns the whole string as one piece"
  (expect (cl-cc/php::%php-array-values-list (cl-cc/php::%php-explode "," "abc"))
          :to-equal (list "abc")))

(it-sequential "implode joins a PHP array with glue"
  (expect (cl-cc/php::%php-implode "," (cl-cc/php::%php-list-to-array (list "a" "b" "c")))
          :to-equal "a,b,c"))

(it-sequential "implode(pieces) with no explicit glue defaults to the empty string"
  (expect (cl-cc/php::%php-implode (cl-cc/php::%php-list-to-array (list "a" "b" "c")) nil)
          :to-equal "abc"))

(it-sequential "join is an alias for implode"
  (expect (cl-cc/php::%php-join "-" (cl-cc/php::%php-list-to-array (list "x" "y")))
          :to-equal "x-y"))

(it-sequential-each
    (("hello" "ll" 2)
     ("hello" "z" nil)
     ("hello" "l" 2))
    "strpos(~S, ~S) => ~S"
    (haystack needle expected)
  (expect (cl-cc/php::%php-strpos haystack needle) :to-equal expected))

(it-sequential "strpos honors a non-zero offset"
  (expect (cl-cc/php::%php-strpos "abcabc" "a" 1) :to-equal 3))

(it-sequential "stripos matches case-insensitively"
  (expect (cl-cc/php::%php-stripos "Hello World" "WORLD") :to-equal 6))

(it-sequential "strrpos returns the LAST occurrence"
  (expect (cl-cc/php::%php-strrpos "abcabc" "a") :to-equal 3)
  (expect (cl-cc/php::%php-strrpos "abcabc" "z") :to-equal nil))

(it-sequential-each
    (("abc" "b" t)
     ("abc" "z" nil))
    "str_contains(~S, ~S) => ~A"
    (haystack needle expected)
  (expect (and (cl-cc/php::%php-str-contains haystack needle) t) :to-be expected))

(it-sequential-each
    (("hello" "he" t)
     ("hello" "lo" nil)
     ("hi" "hello" nil))
    "str_starts_with(~S, ~S) => ~A"
    (haystack needle expected)
  (expect (and (cl-cc/php::%php-str-starts-with haystack needle) t) :to-be expected))

(it-sequential-each
    (("hello" "lo" t)
     ("hello" "he" nil)
     ("hi" "hello" nil))
    "str_ends_with(~S, ~S) => ~A"
    (haystack needle expected)
  (expect (and (cl-cc/php::%php-str-ends-with haystack needle) t) :to-be expected))

(it-sequential "strrev reverses a string"
  (expect (cl-cc/php::%php-strrev "abc") :to-equal "cba")
  (expect (cl-cc/php::%php-strrev "") :to-equal ""))

(it-sequential "str_repeat repeats a string N times, and treats a negative count as zero"
  (expect (cl-cc/php::%php-str-repeat "ab" 3) :to-equal "ababab")
  (expect (cl-cc/php::%php-str-repeat "ab" 0) :to-equal "")
  (expect (cl-cc/php::%php-str-repeat "ab" -5) :to-equal ""))

  )
