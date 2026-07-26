;;;; runtime-builtins-string-transform-test.lisp — src/runtime-builtins-string-transform.lisp —
;;;; transform and compare.

(in-package :cl-cc-php/test)

(describe
  "PHP string transform / compare builtins"
  (it-sequential
    "str_pad pads right by default, left, and both, respecting pad string"
    (expect (cl-cc/php::%php-str-pad "5" 3 "0") :to-equal "500")
    (expect
      (cl-cc/php::%php-str-pad "5" 3 "0" cl-cc/php::+php-str-pad-left+)
      :to-equal
      "005")
    (expect
      (cl-cc/php::%php-str-pad "abc" 7 "*" cl-cc/php::+php-str-pad-both+)
      :to-equal
      "**abc**")
    (expect (cl-cc/php::%php-str-pad "1" 4 "ab") :to-equal "1aba"))
  (it-sequential
    "str_pad returns the string unchanged when no padding is needed or pad is empty"
    (expect (cl-cc/php::%php-str-pad "hello" 3) :to-equal "hello")
    (expect (cl-cc/php::%php-str-pad "hi" 5 "") :to-equal "hi"))
  (it-sequential
    "str_split chunks a string into a PHP array"
    (let ((two (cl-cc/php::%php-str-split "abcd" 2)))
      (expect (cl-cc/php::%php-array-ref two 0) :to-equal "ab")
      (expect (cl-cc/php::%php-array-ref two 1) :to-equal "cd"))
    (let ((one (cl-cc/php::%php-str-split "ab")))
      (expect (cl-cc/php::%php-array-ref one 0) :to-equal "a")
      (expect (cl-cc/php::%php-array-ref one 1) :to-equal "b")))
  (it-sequential
    "substr_count counts non-overlapping occurrences with offset/length and empty needle"
    (expect (cl-cc/php::%php-substr-count "hello world hello" "hello") :to-be 2)
    (expect (cl-cc/php::%php-substr-count "aaa" "aa") :to-be 1)
    (expect (cl-cc/php::%php-substr-count "abcabc" "abc" 1) :to-be 1)
    (expect (cl-cc/php::%php-substr-count "abc" "") :to-be 0))
  (it-sequential
    "substr_replace handles default, explicit, negative start, and negative length"
    (expect (cl-cc/php::%php-substr-replace "Hello" "World" 0) :to-equal "World")
    (expect (cl-cc/php::%php-substr-replace "Hello" "X" 1 3) :to-equal "HXo")
    (expect (cl-cc/php::%php-substr-replace "Hello" "-" -2) :to-equal "Hel-")
    (expect (cl-cc/php::%php-substr-replace "Hello" "-" 1 -1) :to-equal "H-o"))
  (it-sequential
    "ucfirst and lcfirst change the first character, empty string stays empty"
    (expect (cl-cc/php::%php-ucfirst "hello") :to-equal "Hello")
    (expect (cl-cc/php::%php-ucfirst "") :to-equal "")
    (expect (cl-cc/php::%php-lcfirst "Hello") :to-equal "hello")
    (expect (cl-cc/php::%php-lcfirst "") :to-equal ""))
  (it-sequential
    "ucwords uppercases each word and treats only real whitespace as boundaries"
    (expect (cl-cc/php::%php-ucwords "hello world") :to-equal "Hello World")
    (expect (cl-cc/php::%php-ucwords "world") :to-equal "World")
    (expect (cl-cc/php::%php-ucwords "foo-bar" "-") :to-equal "Foo-Bar"))
  (it-sequential
    "ord returns the first byte, 0 for empty string"
    (expect (cl-cc/php::%php-ord "A") :to-be 65)
    (expect (cl-cc/php::%php-ord "") :to-be 0))
  (it-sequential
    "chr masks the codepoint to a single byte"
    (expect (cl-cc/php::%php-chr 65) :to-equal "A")
    (expect (cl-cc/php::%php-chr 321) :to-equal "A"))
  (it-sequential
    "bin2hex and hex2bin round-trip, hex2bin ignores a trailing odd nibble"
    (expect (cl-cc/php::%php-bin2hex "AB") :to-equal "4142")
    (expect (cl-cc/php::%php-hex2bin "4142") :to-equal "AB")
    (expect (cl-cc/php::%php-hex2bin "414") :to-equal "A"))
  (it-sequential
    "strcmp orders binary strings with -1 / 0 / 1"
    (expect (cl-cc/php::%php-strcmp "a" "b") :to-be -1)
    (expect (cl-cc/php::%php-strcmp "b" "a") :to-be 1)
    (expect (cl-cc/php::%php-strcmp "a" "a") :to-be 0))
  (it-sequential
    "strcasecmp compares case-insensitively"
    (expect (cl-cc/php::%php-strcasecmp "ABC" "abc") :to-be 0)
    (expect (cl-cc/php::%php-strcasecmp "a" "B") :to-be -1))
  (it-sequential
    "strncmp compares only the first N characters"
    (expect (cl-cc/php::%php-strncmp "abcXX" "abcYY" 3) :to-be 0)
    (expect (cl-cc/php::%php-strncmp "abc" "abd" 3) :to-be -1))
  (it-sequential
    "strncasecmp compares the first N characters case-insensitively"
    (expect (cl-cc/php::%php-strncasecmp "ABCxx" "abcyy" 3) :to-be 0)
    (expect (cl-cc/php::%php-strncasecmp "aXX" "bYY" 1) :to-be -1)))
