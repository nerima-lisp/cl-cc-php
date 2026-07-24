(in-package :cl-cc-php/test)

(describe
  "PHP extra string builtins"
  (it-sequential
    "is_countable is true for arrays and false for scalars and null"
    (expect
      (cl-cc/php::%php-is-countable (cl-cc/php::%php-make-array))
      :to-be-truthy)
    (expect (cl-cc/php::%php-is-countable "hello") :to-be nil)
    (expect (cl-cc/php::%php-is-countable cl-cc/php::+php-null+) :to-be nil))
  (it-sequential
    "quoted_printable_encode passes printables and hex-escapes the rest"
    (expect (cl-cc/php::%php-quoted-printable-encode "abc") :to-equal "abc")
    (expect (cl-cc/php::%php-quoted-printable-encode "=") :to-equal "=3D")
    (expect (cl-cc/php::%php-quoted-printable-encode "a=b") :to-equal "a=3Db")
    (expect
      (cl-cc/php::%php-quoted-printable-encode (string #\Newline))
      :to-equal
      "=0A"))
  (it-sequential
    "quoted_printable_decode reverses hex escapes and copies the rest"
    (expect (cl-cc/php::%php-quoted-printable-decode "a=3Db") :to-equal "a=b")
    (expect (cl-cc/php::%php-quoted-printable-decode "abc") :to-equal "abc")
    (expect (cl-cc/php::%php-quoted-printable-decode "=3D") :to-equal "="))
  (it-sequential
    "strtr translates per character, only within the shared prefix length"
    (expect (cl-cc/php::%php-strtr "hello" "el" "ip") :to-equal "hippo")
    (expect (cl-cc/php::%php-strtr "abcd" "abc" "xy") :to-equal "xycd"))
  (it-sequential
    "strtr with a pairs array replaces longest keys first"
    (let ((m (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set m "he" "1")
      (cl-cc/php::%php-array-set m "l" "2")
      (expect (cl-cc/php::%php-strtr "hello" m) :to-equal "122o")))
  (it-sequential
    "strpbrk returns from the first matching char, nil when none match"
    (expect (cl-cc/php::%php-strpbrk "hello world" "ow") :to-equal "o world")
    (expect (cl-cc/php::%php-strpbrk "abc" "xyz") :to-be nil))
  (it-sequential
    "strspn measures the leading run of mask characters, honoring start"
    (expect (cl-cc/php::%php-strspn "42 apples" "1234567890") :to-be 2)
    (expect (cl-cc/php::%php-strspn "aaabbb" "a") :to-be 3)
    (expect (cl-cc/php::%php-strspn "aaabbb" "a" 1) :to-be 2))
  (it-sequential
    "strcspn measures the leading run of non-mask characters"
    (expect (cl-cc/php::%php-strcspn "hello" "l") :to-be 2)
    (expect (cl-cc/php::%php-strcspn "abcabc" "xyz") :to-be 6))
  (it-sequential
    "quotemeta backslash-escapes regex metacharacters only"
    (expect (cl-cc/php::%php-quotemeta "1+1=2") :to-equal "1\\+1=2")
    (expect (cl-cc/php::%php-quotemeta "a.b") :to-equal "a\\.b")
    (expect (cl-cc/php::%php-quotemeta "abc") :to-equal "abc"))
  (it-sequential
    "htmlentities escapes the common HTML entities"
    (expect (cl-cc/php::%php-htmlentities "<a>") :to-equal "&lt;a&gt;")
    (expect (cl-cc/php::%php-htmlentities "a&b") :to-equal "a&amp;b"))
  (it-sequential
    "metaphone keeps the uppercase consonant skeleton"
    (expect (cl-cc/php::%php-metaphone "hello") :to-equal "HLL")
    (expect (cl-cc/php::%php-metaphone "Thompson") :to-equal "THMPSN")
    (expect (cl-cc/php::%php-metaphone "a1b2") :to-equal "B")))
