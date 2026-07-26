;;;; runtime-builtins-regex-preg-test.lisp — src/runtime-builtins-regex-preg.lisp — the preg_*
;;;; engine.

(in-package :cl-cc-php/test)

(describe
  "PHP preg_* regex engine and builtins"
  (it-sequential
    "strip-pattern separates the /pattern/ body from its flags"
    (multiple-value-bind (pat flags) (cl-cc/php::%php-strip-pattern "/abc/i")
      (expect pat :to-equal "abc")
      (expect flags :to-equal "i"))
    (multiple-value-bind (pat flags) (cl-cc/php::%php-strip-pattern "/a.b/")
      (expect pat :to-equal "a.b")
      (expect flags :to-equal ""))
    (multiple-value-bind (pat flags) (cl-cc/php::%php-strip-pattern "abc")
      (expect pat :to-equal "abc")
      (expect flags :to-equal "")))
  (it-sequential
    "preg_match returns 1 on a match and 0 otherwise"
    (expect (cl-cc/php::%php-preg-match "/hello/" "hello world") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/xyz/" "hello world") :to-be 0))
  (it-sequential
    "preg_match honors the case-insensitive flag"
    (expect (cl-cc/php::%php-preg-match "/HELLO/i" "hello") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/HELLO/" "hello") :to-be 0))
  (it-sequential
    "preg_match anchors ^ and $ to the whole subject by default"
    (expect (cl-cc/php::%php-preg-match "/^abc/" "abcdef") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/^abc/" "xabcdef") :to-be 0)
    (expect (cl-cc/php::%php-preg-match "/def$/" "abcdef") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/def$/" "abcdefg") :to-be 0))
  (it-sequential
    "preg_match with the m flag anchors ^ after newlines"
    (expect
      (cl-cc/php::%php-preg-match "/^world/m" (format nil "hello~%world"))
      :to-be
      1)
    (expect
      (cl-cc/php::%php-preg-match "/^world/" (format nil "hello~%world"))
      :to-be
      0))
  (it-sequential
    "preg_match matches character classes, ranges, and complements"
    (expect (cl-cc/php::%php-preg-match "/[0-9]+/" "abc123") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/[0-9]+/" "abcdef") :to-be 0)
    (expect (cl-cc/php::%php-preg-match "/[a-c]+/" "cab") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/[^0-9]/" "abc") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/[^0-9]/" "123") :to-be 0))
  (it-sequential
    "preg_match handles alternation and optional/star/plus quantifiers"
    (expect (cl-cc/php::%php-preg-match "/cat|dog/" "I have a dog") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/cat|dog/" "I have a bird") :to-be 0)
    (expect (cl-cc/php::%php-preg-match "/colou?r/" "color") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/colou?r/" "colour") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/ab*c/" "ac") :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/ab*c/" "abbbc") :to-be 1))
  (it-sequential
    "preg_match applies OFFSET before scanning"
    (expect (cl-cc/php::%php-preg-match "/a/" "banana" nil nil 2) :to-be 1)
    (expect (cl-cc/php::%php-preg-match "/b/" "banana" nil nil 2) :to-be 0))
  (it-sequential
    "preg_match_all counts every non-overlapping match by scanning forward"
    (expect (cl-cc/php::%php-preg-match-all "/\\d/" "1a2b3") :to-be 3)
    (expect (cl-cc/php::%php-preg-match-all "/x/" "abc") :to-be 0)
    (expect (cl-cc/php::%php-preg-match-all "/ab/" "ababab") :to-be 3))
  (it-sequential
    "preg_match matches populate group 0 and each capture group"
    (let ((m (cl-cc/php::%php-preg-match-matches "/(\\d+)-(\\d+)/" "12-34")))
      (expect (cl-cc/php::%php-array-ref m 0) :to-equal "12-34")
      (expect (cl-cc/php::%php-array-ref m 1) :to-equal "12")
      (expect (cl-cc/php::%php-array-ref m 2) :to-equal "34"))
    (expect
      (cl-cc/php::%php-count (cl-cc/php::%php-preg-match-matches "/xyz/" "abc"))
      :to-be
      0))
  (it-sequential
    "a non-participating optional group yields an empty string"
    (let ((m (cl-cc/php::%php-preg-match-matches "/a(x)?b/" "ab")))
      (expect (cl-cc/php::%php-array-ref m 0) :to-equal "ab")
      (expect (cl-cc/php::%php-array-ref m 1) :to-equal "")))
  (it-sequential
    "preg_match_all matches build PREG_PATTERN_ORDER per-group arrays"
    (let ((m (cl-cc/php::%php-preg-match-all-matches "/(\\d)/" "1a2b3")))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref m 0))
        :to-equal
        '("1" "2" "3"))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref m 1))
        :to-equal
        '("1" "2" "3"))))
  (it-sequential
    "preg_replace substitutes all matches and expands backreferences"
    (expect (cl-cc/php::%php-preg-replace "/\\d/" "#" "a1b2c3") :to-equal "a#b#c#")
    (expect
      (cl-cc/php::%php-preg-replace "/(\\w+)@(\\w+)/" "$2.$1" "user@host")
      :to-equal
      "host.user")
    (expect (cl-cc/php::%php-preg-replace "/xyz/" "#" "abc") :to-equal "abc"))
  (it-sequential
    "preg_split divides the subject, respecting a positive limit"
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-preg-split "/,/" "a,b,c"))
      :to-equal
      '("a" "b" "c"))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-preg-split "/\\s+/" "a  b   c"))
      :to-equal
      '("a" "b" "c"))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-preg-split "/,/" "a,b,c,d" 2))
      :to-equal
      '("a" "b,c,d")))
  (it-sequential
    "preg_quote escapes regex metacharacters"
    (expect (cl-cc/php::%php-preg-quote "a.b*c") :to-equal "a\\.b\\*c")
    (expect (cl-cc/php::%php-preg-quote "1+1") :to-equal "1\\+1")))
