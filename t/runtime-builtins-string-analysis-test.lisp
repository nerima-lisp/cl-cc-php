;;;; runtime-builtins-string-analysis-test.lisp — src/runtime-builtins-string-analysis.lisp —
;;;; string search, word counting, edit-distance/similarity, and the printf family.
;;;;
;;;; Before this file, strstr/stristr/strchr/str_word_count/levenshtein/similar_text/soundex/
;;;; printf/vsprintf/vprintf had zero coverage of any kind — no direct unit test and no PHP-source
;;;; e2e test either.

(in-package :cl-cc-php/test)

(describe "PHP strstr/stristr/strchr"

(it-sequential "strstr returns the needle onward, or the prefix before it"
  (expect (cl-cc/php::%php-strstr "user@example.com" "@") :to-equal "@example.com")
  (expect (cl-cc/php::%php-strstr "user@example.com" "@" t) :to-equal "user")
  (expect (cl-cc/php::%php-strstr "no-match-here" "@") :to-be nil))

(it-sequential "stristr is case-insensitive strstr"
  (expect (cl-cc/php::%php-stristr "USER@example.com" "@") :to-equal "@example.com")
  (expect (cl-cc/php::%php-stristr "Hello World" "WORLD") :to-equal "World"))

(it-sequential "strchr is an alias for strstr"
  (expect (cl-cc/php::%php-strchr "user@example.com" "@") :to-equal "@example.com"))

  )

(describe "PHP str_word_count"

(it-sequential "format 0 (default) returns the word count"
  (expect (cl-cc/php::%php-str-word-count "Hello fair world") :to-be 3)
  (expect (cl-cc/php::%php-str-word-count "") :to-be 0))

(it-sequential "format 1 returns an array of the words in order"
  (let ((r (cl-cc/php::%php-str-word-count "Hello fair world" 1)))
    (expect (cl-cc/php::%php-array-ref r 0) :to-equal "Hello")
    (expect (cl-cc/php::%php-array-ref r 1) :to-equal "fair")
    (expect (cl-cc/php::%php-array-ref r 2) :to-equal "world")))

(it-sequential "format 2 returns an array of position => word"
  (let ((r (cl-cc/php::%php-str-word-count "Hello fair world" 2)))
    (expect (cl-cc/php::%php-array-ref r 0) :to-equal "Hello")
    (expect (cl-cc/php::%php-array-ref r 6) :to-equal "fair")
    (expect (cl-cc/php::%php-array-ref r 11) :to-equal "world")))

(it-sequential "splits on any non-alpha character, including an apostrophe inside a word"
  ;; PHP's real str_word_count treats a `'`/`-` between two letters as part of the same word by
  ;; default; this implementation's ALPHA-CHAR-P-only test does not, so "don't" splits into two
  ;; words here. Documented as this runtime's actual behavior, not silently left unasserted.
  (expect (cl-cc/php::%php-str-word-count "don't stop") :to-be 3))

  )

(describe "PHP levenshtein"

(it-sequential "counts single-character edits between two strings"
  (expect (cl-cc/php::%php-levenshtein "kitten" "sitting") :to-be 3)
  (expect (cl-cc/php::%php-levenshtein "same" "same") :to-be 0)
  (expect (cl-cc/php::%php-levenshtein "" "abc") :to-be 3))

  )

(describe "PHP similar_text: the real longest-common-substring recursion, not a naive char scan"
  ;; The original implementation counted, for each character of S1, whether that character value
  ;; occurred ANYWHERE in S2 at all (no position tracking) — not PHP's actual algorithm (longest
  ;; common substring, then recurse on the parts before and after it on both sides). The two
  ;; algorithms coincidentally agree on some inputs (e.g. PHP's own manual example, "World"/"Word")
  ;; but diverge on others: the old code returned 2, not PHP's real 1, for ("ab", "ba").

(it-sequential "matches PHP's manual example: similar_text('World', 'Word') === 4"
  (expect (cl-cc/php::%php-similar-text "World" "Word") :to-be 4))

(it-sequential "the old naive char-scan overcounted (\"ab\",\"ba\") as 2; the real answer is 1"
  (expect (cl-cc/php::%php-similar-text "ab" "ba") :to-be 1))

(it-sequential "identical strings are fully similar; disjoint strings share nothing"
  (expect (cl-cc/php::%php-similar-text "same" "same") :to-be 4)
  (expect (cl-cc/php::%php-similar-text "abc" "xyz") :to-be 0))

(it-sequential "either argument empty is defined as zero similarity"
  (expect (cl-cc/php::%php-similar-text "" "abc") :to-be 0)
  (expect (cl-cc/php::%php-similar-text "abc" "") :to-be 0))

(it-sequential "percent-var, when a PHP reference, receives common*2/(len1+len2)*100"
  (let ((ref (cl-cc/php::%php-make-ref nil)))
    (expect (cl-cc/php::%php-similar-text "World" "Word" ref) :to-be 4)
    (expect (cl-cc/php::%php-deref ref) :to-equal (/ (* 4 2.0d0 100) 9))))

(it-sequential "percent-var is safely ignored when it is not a PHP reference"
  (expect (cl-cc/php::%php-similar-text "World" "Word" nil) :to-be 4))

  )

(describe "PHP similar_text end-to-end: the compiled $percent by-reference output parameter"

(it-sequential "php-e2e-similar-text-return-value"
  (expect (%php-run-capture "<?php echo similar_text('World', 'Word');")
          :to-equal "4"))

(it-sequential "php-e2e-similar-text-percent-out-param"
  (expect (%php-run-capture
           "<?php $p = null; similar_text('World', 'Word', $p); echo round($p, 2);")
          :to-equal "88.89"))

  )

(describe "PHP soundex"

(it-sequential "encodes common examples to their known Soundex codes"
  (expect (cl-cc/php::%php-soundex "Robert") :to-equal "R163")
  (expect (cl-cc/php::%php-soundex "Rupert") :to-equal "R163")
  (expect (cl-cc/php::%php-soundex "Ashcraft") :to-equal "A261")
  (expect (cl-cc/php::%php-soundex "") :to-equal ""))

  )

(describe "PHP printf/vsprintf/vprintf: the output-writing half of the sprintf family"

(it-sequential "php-e2e-printf-writes-formatted-output-and-returns-its-length"
  (expect (%php-run-capture "<?php $n = printf('%d-%s', 5, 'x'); echo '|' . $n;")
          :to-equal "5-x|3"))

(it-sequential "php-e2e-vsprintf-formats-from-an-array-without-writing"
  (expect (%php-run-capture "<?php echo vsprintf('%d-%s', [5, 'x']);")
          :to-equal "5-x"))

(it-sequential "php-e2e-vprintf-writes-formatted-output-and-returns-its-length"
  (expect (%php-run-capture "<?php $n = vprintf('%d-%s', [5, 'x']); echo '|' . $n;")
          :to-equal "5-x|3"))

  )
