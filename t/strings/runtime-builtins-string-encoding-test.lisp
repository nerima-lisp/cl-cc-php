;;;; runtime-builtins-string-encoding-test.lisp — src/runtime-builtins-string-encoding.lisp — HTML
;;;; and byte encoding.

(in-package :cl-cc-php/test)

(describe
  "PHP HTML and byte string encoding builtins"
  (it-sequential
    "nl2br inserts <br /> by default and <br> when not XHTML"
    (expect
      (cl-cc/php::%php-nl2br (format nil "a~%b"))
      :to-equal
      (format nil "a<br />~%b"))
    (expect
      (cl-cc/php::%php-nl2br (format nil "a~%b") nil)
      :to-equal
      (format nil "a<br>~%b"))
    (expect (cl-cc/php::%php-nl2br "no newline") :to-equal "no newline"))
  (it-sequential
    "wordwrap breaks on spaces, moves long words to a fresh line, and cuts when asked"
    (expect
      (cl-cc/php::%php-wordwrap "The quick brown fox" 10)
      :to-equal
      (format nil "The quick~%brown fox"))
    (expect (cl-cc/php::%php-wordwrap "abcdefghij" 4) :to-equal "abcdefghij")
    (expect
      (cl-cc/php::%php-wordwrap "abcdefghij" 4 (format nil "~%") t)
      :to-equal
      (format nil "abcd~%efgh~%ij")))
  (it-sequential
    "chunk_split appends the terminator after each fixed-size chunk"
    (expect (cl-cc/php::%php-chunk-split "abcdefgh" 3 "-") :to-equal "abc-def-gh-")
    (expect (cl-cc/php::%php-chunk-split "abc" 3 "-") :to-equal "abc-")
    (expect (cl-cc/php::%php-chunk-split "abcd" 2 "|") :to-equal "ab|cd|"))
  (it-sequential
    "html_entity_decode converts the common named entities"
    (expect (cl-cc/php::%php-html-entity-decode "&lt;b&gt;") :to-equal "<b>")
    (expect
      (cl-cc/php::%php-html-entity-decode "&quot;hi&quot;")
      :to-equal
      "\"hi\"")
    (expect (cl-cc/php::%php-html-entity-decode "&nbsp;") :to-equal " ")
    (expect (cl-cc/php::%php-html-entity-decode "plain") :to-equal "plain"))
  (it-sequential
    "strip_tags removes angle-bracket-delimited tags"
    (expect (cl-cc/php::%php-strip-tags "<b>hello</b>") :to-equal "hello")
    (expect (cl-cc/php::%php-strip-tags "a<br/>b") :to-equal "ab")
    (expect (cl-cc/php::%php-strip-tags "plain") :to-equal "plain"))
  (it-sequential
    "addslashes escapes quotes and backslashes"
    (expect (cl-cc/php::%php-addslashes "O'Reilly") :to-equal "O\\'Reilly")
    (expect (cl-cc/php::%php-addslashes "say \"hi\"") :to-equal "say \\\"hi\\\"")
    (expect (cl-cc/php::%php-addslashes "a\\b") :to-equal "a\\\\b"))
  (it-sequential
    "stripslashes reverses addslashes escaping"
    (expect (cl-cc/php::%php-stripslashes "O\\'Reilly") :to-equal "O'Reilly")
    (expect (cl-cc/php::%php-stripslashes "a\\\\b") :to-equal "a\\b")
    (expect (cl-cc/php::%php-stripslashes "plain") :to-equal "plain"))
  (it-sequential
    "base64_encode pads according to the input length modulo three"
    (expect (cl-cc/php::%php-base64-encode "Man") :to-equal "TWFu")
    (expect (cl-cc/php::%php-base64-encode "Ma") :to-equal "TWE=")
    (expect (cl-cc/php::%php-base64-encode "M") :to-equal "TQ=="))
  (it-sequential
    "base64_decode round-trips encoded input, honoring padding"
    (expect (cl-cc/php::%php-base64-decode "TWFu") :to-equal "Man")
    (expect (cl-cc/php::%php-base64-decode "TWE=") :to-equal "Ma")
    (expect (cl-cc/php::%php-base64-decode "TQ==") :to-equal "M"))
  (it-sequential
    "string bytes render as lowercase hex"
    (expect
      (cl-cc/php::%php-byte-vector-hex (cl-cc/php::%php-string-bytes "AB"))
      :to-equal
      "4142")
    (expect
      (cl-cc/php::%php-byte-vector-hex (cl-cc/php::%php-string-bytes ""))
      :to-equal
      ""))
  (it-sequential
    "urlencode maps spaces to plus and percent-encodes reserved characters"
    (expect (cl-cc/php::%php-urlencode "a b") :to-equal "a+b")
    (expect (cl-cc/php::%php-urlencode "a/b") :to-equal "a%2Fb")
    (expect (cl-cc/php::%php-urlencode "a-b_c.d~e") :to-equal "a-b_c.d~e"))
  (it-sequential
    "urldecode reverses plus and percent encoding"
    (expect (cl-cc/php::%php-urldecode "a+b") :to-equal "a b")
    (expect (cl-cc/php::%php-urldecode "a%2Fb") :to-equal "a/b")
    (expect (cl-cc/php::%php-urldecode "plain") :to-equal "plain"))
  (it-sequential
    "rawurlencode and rawurldecode delegate to the url variants"
    (expect (cl-cc/php::%php-rawurlencode "a b") :to-equal "a+b")
    (expect (cl-cc/php::%php-rawurldecode "a%2Fb") :to-equal "a/b"))
  (it-sequential
    "htmlspecialchars_decode converts the five special entities"
    (expect (cl-cc/php::%php-htmlspecialchars-decode "&lt;a&gt;") :to-equal "<a>")
    (expect (cl-cc/php::%php-htmlspecialchars-decode "&amp;") :to-equal "&")
    (expect (cl-cc/php::%php-htmlspecialchars-decode "&quot;") :to-equal "\"")
    (expect (cl-cc/php::%php-htmlspecialchars-decode "&#039;") :to-equal "'")))
