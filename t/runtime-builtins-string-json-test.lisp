;;;; runtime-builtins-string-json-test.lisp — src/runtime-builtins-string-json.lisp — json_encode/
;;;; json_decode/json_validate and the pure helpers underneath them.
;;;;
;;;; json_encode/json_decode's happy paths are already exercised by PHP-source e2e tests
;;;; elsewhere; this file covers what those never reach directly: %php-json-quote-string's escape
;;;; table, JSON_PRETTY_PRINT formatting, json_decode's malformed-input-returns-null tolerance, and
;;;; json_validate — which, before this file, had zero coverage of its actual validation behaviour.

(in-package :cl-cc-php/test)

(describe "PHP json_encode: scalar and pretty-printed encoding"

(it-sequential "encodes scalars, arrays, and associative arrays"
  (expect (cl-cc/php::%php-json-encode 42) :to-equal "42")
  (expect (cl-cc/php::%php-json-encode cl-cc/php::+php-null+) :to-equal "null")
  (expect (cl-cc/php::%php-json-encode t) :to-equal "true")
  (expect (cl-cc/php::%php-json-encode nil) :to-equal "false"))

(it-sequential "JSON_PRETTY_PRINT (128) adds 4-space indentation and a space after each colon"
  (let ((arr (cl-cc/php::%php-make-array)))
    (cl-cc/php::%php-array-set arr "a" 1)
    (expect (cl-cc/php::%php-json-encode arr 128)
            :to-equal (format nil "{~%    \"a\": 1~%}"))))

  )

(describe "PHP %php-json-quote-string: the JSON string escape table"

(it-sequential "escapes quote, backslash, and the C0 control characters PHP always escapes"
  (expect (cl-cc/php::%php-json-quote-string "a\"b") :to-equal "\"a\\\"b\"")
  (expect (cl-cc/php::%php-json-quote-string "a\\b") :to-equal "\"a\\\\b\"")
  (expect (cl-cc/php::%php-json-quote-string (format nil "a~Ab" #\Newline)) :to-equal "\"a\\nb\"")
  (expect (cl-cc/php::%php-json-quote-string (format nil "a~Ab" #\Tab)) :to-equal "\"a\\tb\""))

(it-sequential "passes ordinary characters through unescaped"
  (expect (cl-cc/php::%php-json-quote-string "hello") :to-equal "\"hello\""))

  )

(describe "PHP json_decode: malformed input tolerantly decodes to null instead of signalling"
  ;; %PHP-JSON-PARSE-VALUE's catch-all branch never signals — every unrecognised token falls
  ;; through to (values +php-null+ (1+ pos)) — so json_decode can never raise on bad input,
  ;; matching PHP's own "returns null on error" contract but never PHP's JSON_THROW_ON_ERROR
  ;; flag, which this implementation does not honour (the FLAGS argument is ignored).

(it-sequential "decodes well-formed JSON"
  (expect (cl-cc/php::%php-json-decode "42") :to-be 42)
  (expect (cl-cc/php::%php-json-decode "\"hi\"") :to-equal "hi"))

(it-sequential "malformed input decodes to null rather than signalling"
  (expect (cl-cc/php::%php-json-decode "not valid json at all {{{")
          :to-be cl-cc/php::+php-null+)
  (expect (cl-cc/php::%php-json-decode "") :to-be cl-cc/php::+php-null+))

  )

(describe "PHP json_validate (8.3): actually rejects malformed JSON"
  ;; Before this fix, JSON-VALIDATE ran %PHP-JSON-DECODE inside a HANDLER-CASE for ERROR, but
  ;; decode's parser never signals (see above) — so the handler-case's error branch was
  ;; structurally unreachable and json_validate always returned T, for any input. It now
  ;; delegates to cl-json-kit's JSON-KIT:PARSE, a dependency-free, RFC 8259-conformance-tested
  ;; JSON reader (nerima-lisp/cl-json-kit) that already rejects trailing data after the value.

(it-sequential "accepts well-formed JSON of every top-level shape"
  (expect (cl-cc/php::%php-json-validate "123") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "\"hi\"") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "true") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "null") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "[1,2,3]") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "{\"a\":1,\"b\":[2,3]}") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "  42  ") :to-be-truthy))

(it-sequential "rejects unrecognisable input"
  (expect (cl-cc/php::%php-json-validate "not valid json at all {{{") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "}") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "") :to-be nil))

(it-sequential "rejects trailing garbage after an otherwise-valid value"
  (expect (cl-cc/php::%php-json-validate "123abc") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "nullx") :to-be nil))

(it-sequential "rejects unbalanced/unterminated structures"
  (expect (cl-cc/php::%php-json-validate "{\"a\":1") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "[1,2,") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "\"unterminated") :to-be nil))

(it-sequential "rejects a leading zero before more digits, per RFC 8259"
  ;; A hand-rolled digit-scanning number parser easily misses this one — the digits are all
  ;; individually valid, only their leading-zero arrangement isn't. cl-json-kit's parser is
  ;; RFC 8259-conformance-tested against the JSONTestSuite corpus, which pins exactly this case.
  (expect (cl-cc/php::%php-json-validate "01") :to-be nil)
  (expect (cl-cc/php::%php-json-validate "0") :to-be-truthy)
  (expect (cl-cc/php::%php-json-validate "0.5") :to-be-truthy))

  )
