;;;; runtime-builtins-io-cookie-session-test.lisp — src/runtime-builtins-io-cookie-session.lisp —
;;;; the small option-coercion and HTTP-date helpers underneath setcookie/session_*.
;;;;
;;;; The high-level setcookie()/session_*() builtins are already exercised extensively by
;;;; PHP-source e2e tests (see runtime-builtins-io-cookie-session-php85-test.lisp and the e2e
;;;; suites); this file covers the small pure helpers underneath them directly, none of which any
;;;; existing test called by name.

(in-package :cl-cc-php/test)

(describe "PHP cookie option coercion helpers"

(it-sequential "cookie-string uses DEFAULT for null/omitted, stringifies otherwise"
  (expect (cl-cc/php::%php-cookie-string cl-cc/php::+php-null+ "fallback") :to-equal "fallback")
  (expect (cl-cc/php::%php-cookie-string nil "fallback") :to-equal "fallback")
  (expect (cl-cc/php::%php-cookie-string 42) :to-equal "42"))

(it-sequential "cookie-integer uses DEFAULT for null/omitted, coerces otherwise"
  (expect (cl-cc/php::%php-cookie-integer cl-cc/php::+php-null+ 7) :to-be 7)
  (expect (cl-cc/php::%php-cookie-integer "42") :to-be 42))

(it-sequential "cookie-bool is false for PHP null, otherwise PHP truthiness"
  (expect (cl-cc/php::%php-cookie-bool cl-cc/php::+php-null+) :to-be nil)
  (expect (cl-cc/php::%php-cookie-bool t) :to-be-truthy)
  (expect (cl-cc/php::%php-cookie-bool nil) :to-be nil)
  (expect (cl-cc/php::%php-cookie-bool 1) :to-be-truthy))

(it-sequential "cookie-samesite accepts Strict/Lax/None/empty, case-insensitively"
  (expect (cl-cc/php::%php-cookie-samesite "setcookie" "Strict") :to-equal "Strict")
  (expect (cl-cc/php::%php-cookie-samesite "setcookie" "lax") :to-equal "lax")
  (expect (cl-cc/php::%php-cookie-samesite "setcookie" cl-cc/php::+php-null+) :to-equal ""))

(it-sequential "cookie-samesite signals a ValueError for anything else"
  (signals cl-cc/php:php-exception (cl-cc/php::%php-cookie-samesite "setcookie" "Relaxed")))

  )

(describe "PHP cookie Expires HTTP-date formatting"

(it-sequential "cookie-weekday-name/cookie-month-name index into the RFC-1123 abbreviation tables"
  (expect (cl-cc/php::%php-cookie-weekday-name 3) :to-equal "Thu")
  (expect (cl-cc/php::%php-cookie-weekday-name 6) :to-equal "Sun")
  (expect (cl-cc/php::%php-cookie-month-name 1) :to-equal "Jan")
  (expect (cl-cc/php::%php-cookie-month-name 12) :to-equal "Dec"))

(it-sequential "cookie-expires-gmt formats a Unix timestamp as an RFC-1123 HTTP-date"
  ;; Unix epoch 0 = 1970-01-01T00:00:00Z, a Thursday.
  (expect (cl-cc/php::%php-cookie-expires-gmt 0) :to-equal "Thu, 01 Jan 1970 00:00:00 GMT")
  ;; +90061s = 1 day, 1 hour, 1 minute, 1 second past epoch = 1970-01-02T01:01:01Z, a Friday.
  (expect (cl-cc/php::%php-cookie-expires-gmt 90061) :to-equal "Fri, 02 Jan 1970 01:01:01 GMT"))

  )

(describe "PHP session_start($options) option-merging: %php-session-apply-start-options"
  ;; Not exercised by name anywhere before this file — only the high-level session_start()
  ;; PHP-source e2e tests reach it indirectly. *PHP-SESSION-NAME*/*PHP-SESSION-COOKIE-PARAMS* are
  ;; DEFVARs, so each test LET-binds them to avoid leaking session state into other tests.

(it-sequential "merges every cookie_* option into the modeled session cookie params"
  (let ((cl-cc/php::*php-session-cookie-params* nil)
        (cl-cc/php::*php-session-name* "PHPSESSID"))
    (let ((options (cl-cc/php::%php-make-array)))
      (cl-cc/php::%php-array-set options "name" "MYSESSID")
      (cl-cc/php::%php-array-set options "cookie_lifetime" 3600)
      (cl-cc/php::%php-array-set options "cookie_path" "/app")
      (cl-cc/php::%php-array-set options "cookie_domain" "example.com")
      (cl-cc/php::%php-array-set options "cookie_secure" t)
      (cl-cc/php::%php-array-set options "cookie_httponly" t)
      (cl-cc/php::%php-array-set options "cookie_samesite" "Strict")
      (cl-cc/php::%php-session-apply-start-options options)
      (expect cl-cc/php::*php-session-name* :to-equal "MYSESSID")
      (let ((params cl-cc/php::*php-session-cookie-params*))
        (expect (cl-cc/php::%php-array-ref params "lifetime") :to-be 3600)
        (expect (cl-cc/php::%php-array-ref params "path") :to-equal "/app")
        (expect (cl-cc/php::%php-array-ref params "domain") :to-equal "example.com")
        (expect (cl-cc/php::%php-array-ref params "secure") :to-be-truthy)
        (expect (cl-cc/php::%php-array-ref params "httponly") :to-be-truthy)
        (expect (cl-cc/php::%php-array-ref params "samesite") :to-equal "Strict")))))

(it-sequential "an omitted cookie_* option falls back to the existing session cookie param, not
the hard-coded default"
  (let* ((existing (cl-cc/php::%php-make-array))
         (cl-cc/php::*php-session-cookie-params*
           (progn (cl-cc/php::%php-array-set existing "lifetime" 42)
                  (cl-cc/php::%php-array-set existing "path" "/kept")
                  (cl-cc/php::%php-array-set existing "domain" "")
                  (cl-cc/php::%php-array-set existing "secure" nil)
                  (cl-cc/php::%php-array-set existing "partitioned" nil)
                  (cl-cc/php::%php-array-set existing "httponly" nil)
                  (cl-cc/php::%php-array-set existing "samesite" "")
                  existing))
         (cl-cc/php::*php-session-name* "PHPSESSID"))
    ;; No "name"/cookie_lifetime/cookie_path key at all — an empty options array.
    (cl-cc/php::%php-session-apply-start-options (cl-cc/php::%php-make-array))
    (expect cl-cc/php::*php-session-name* :to-equal "PHPSESSID")
    (let ((params cl-cc/php::*php-session-cookie-params*))
      (expect (cl-cc/php::%php-array-ref params "lifetime") :to-be 42)
      (expect (cl-cc/php::%php-array-ref params "path") :to-equal "/kept"))))

  )
