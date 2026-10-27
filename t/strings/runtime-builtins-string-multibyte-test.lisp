;;;; runtime-builtins-string-multibyte-test.lisp — src/runtime-builtins-string-multibyte.lisp — the
;;;; mb_* builtins.

(in-package :cl-cc-php/test)

(describe
  "PHP mb_* multibyte string builtins"
  (it-sequential
    "mb_strlen counts characters, empty string is zero"
    (expect (cl-cc/php::%php-mb-strlen "hello") :to-be 5)
    (expect (cl-cc/php::%php-mb-strlen "") :to-be 0)
    (expect (cl-cc/php::%php-mb-strlen "hello" "UTF-8") :to-be 5))
  (it-sequential
    "mb_substr handles positive, negative, and default length"
    (expect (cl-cc/php::%php-mb-substr "hello" 1 3) :to-equal "ell")
    (expect (cl-cc/php::%php-mb-substr "hello" 2) :to-equal "llo")
    (expect (cl-cc/php::%php-mb-substr "hello" -2) :to-equal "lo")
    (expect (cl-cc/php::%php-mb-substr "hello" 1 -1) :to-equal "ell"))
  (it-sequential
    "mb_strtolower and mb_strtoupper change case"
    (expect (cl-cc/php::%php-mb-strtolower "HeLLo") :to-equal "hello")
    (expect (cl-cc/php::%php-mb-strtoupper "HeLLo") :to-equal "HELLO"))
  (it-sequential
    "mb_strpos finds needle, honors offset, returns nil when absent"
    (expect (cl-cc/php::%php-mb-strpos "hello world" "world") :to-be 6)
    (expect (cl-cc/php::%php-mb-strpos "hello" "z") :to-be nil)
    (expect (cl-cc/php::%php-mb-strpos "abcabc" "abc" 1) :to-be 3)
    (expect (cl-cc/php::%php-mb-strpos "abcabc" "c" -2) :to-be 5))
  (it-sequential
    "mb_strrpos finds the last occurrence"
    (expect (cl-cc/php::%php-mb-strrpos "abcabc" "abc") :to-be 3)
    (expect (cl-cc/php::%php-mb-strrpos "hello" "z") :to-be nil))
  (it-sequential
    "mb_substr_count counts non-overlapping occurrences"
    (expect (cl-cc/php::%php-mb-substr-count "hello" "l") :to-be 2)
    (expect (cl-cc/php::%php-mb-substr-count "abababa" "aba") :to-be 2))
  (it-sequential
    "mb_detect_encoding and mb_internal_encoding report UTF-8"
    (expect (cl-cc/php::%php-mb-detect-encoding "hello") :to-equal "UTF-8")
    (expect (cl-cc/php::%php-mb-internal-encoding) :to-equal "UTF-8"))
  (it-sequential
    "mb_convert_encoding passes the string through unchanged"
    (expect (cl-cc/php::%php-mb-convert-encoding "hello" "UTF-8") :to-equal "hello")
    (expect
      (cl-cc/php::%php-mb-convert-encoding "hello" "UTF-8" "ISO-8859-1")
      :to-equal
      "hello"))
  (it-sequential
    "mb_strtolower with an explicit encoding lowercases"
    (expect (cl-cc/php::%php-mb-strtolower-encoding "ABC" "UTF-8") :to-equal "abc"))
  (it-sequential
    "mb_convert_case switches on the mode constant"
    (expect (cl-cc/php::%php-mb-convert-case "hello" 0) :to-equal "HELLO")
    (expect (cl-cc/php::%php-mb-convert-case "HELLO" 1) :to-equal "hello")
    (expect
      (cl-cc/php::%php-mb-convert-case "hello world" 2)
      :to-equal
      "Hello World")
    (expect (cl-cc/php::%php-mb-convert-case "hello" 99) :to-equal "hello"))
  (it-sequential
    "mb_str_pad pads left, right, both, defaults, and no-ops when long enough"
    (expect (cl-cc/php::%php-mb-str-pad "5" 3 "0" 0) :to-equal "005")
    (expect (cl-cc/php::%php-mb-str-pad "5" 3 "0" 1) :to-equal "500")
    (expect (cl-cc/php::%php-mb-str-pad "x" 4 "-" 2) :to-equal "-x--")
    (expect (cl-cc/php::%php-mb-str-pad "hi" 5) :to-equal "hi   ")
    (expect (cl-cc/php::%php-mb-str-pad "hello" 3) :to-equal "hello"))
  (it-sequential
    "mb_str_split chunks the string, defaulting to length 1"
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-mb-str-split "abcdef" 2))
      :to-equal
      '("ab" "cd" "ef"))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-mb-str-split "abc"))
      :to-equal
      '("a" "b" "c")))
  (it-sequential
    "str_getcsv splits fields, strips enclosures, honors a custom separator"
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-str-getcsv "a,b,c"))
      :to-equal
      '("a" "b" "c"))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-str-getcsv "\"a\",\"b\""))
      :to-equal
      '("a" "b"))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-str-getcsv "a;b;c" ";"))
      :to-equal
      '("a" "b" "c")))
  (it-sequential
    "mb_chr and mb_ord round-trip a code point, mb_ord on empty is nil"
    (expect (cl-cc/php::%php-mb-chr 65) :to-equal "A")
    (expect (cl-cc/php::%php-mb-ord "A") :to-be 65)
    (expect (cl-cc/php::%php-mb-ord "") :to-be nil))
  (it-sequential
    "mb_strimwidth truncates with a trim marker, leaves short strings alone"
    (expect
      (cl-cc/php::%php-mb-strimwidth "Hello World" 0 6 "...")
      :to-equal
      "Hello ...")
    (expect (cl-cc/php::%php-mb-strimwidth "Hi" 0 10) :to-equal "Hi")
    (expect (cl-cc/php::%php-mb-strimwidth "Hello" 2 2) :to-equal "ll"))
  (it-sequential
    "mb_ereg and mb_eregi match literal patterns"
    (expect (cl-cc/php::%php-mb-ereg "ell" "hello") :to-be-truthy)
    (expect (cl-cc/php::%php-mb-ereg "xyz" "hello") :to-be nil)
    (expect (cl-cc/php::%php-mb-eregi "ELL" "hello") :to-be-truthy))
  (it-sequential
    "mb_ereg_replace and mb_eregi_replace substitute matches"
    (expect (cl-cc/php::%php-mb-ereg-replace "l" "L" "hello") :to-equal "heLLo")
    (expect (cl-cc/php::%php-mb-eregi-replace "L" "x" "hello") :to-equal "hexxo"))
  (it-sequential
    "mb_split splits a string on a literal regex"
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-mb-split "," "a,b,c"))
      :to-equal
      '("a" "b" "c"))))
