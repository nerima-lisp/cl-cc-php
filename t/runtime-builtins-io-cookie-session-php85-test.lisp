;;;; runtime-builtins-io-cookie-session-php85-test.lisp — src/runtime-builtins-io-cookie-session.lisp
;;;; — the PHP 8.5 partitioned-cookie additions to setcookie/setrawcookie/session cookie params.
;;;;
;;;; Split out of runtime-builtins-io-tokenizer-php85-test.lisp, which stayed over the 500-line
;;;; limit even after the split: these ten tests are the ones that exercise the cookie/session
;;;; builtins specifically, rather than the tokenizer/image/filter grab-bag the parent file covers.

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 partitioned cookies and session cookie params"
  (it-sequential
    "PHP 8.5 setcookie() accepts partitioned cookies when secure is enabled."
    (let ((cl-cc/php::*php-http-response-code* 200)
          (cl-cc/php::*php-http-headers* nil)
          (cl-cc/php::*php-output-started-p* nil))
      (expect
        (%php-run-capture
          "<?php
setcookie('chip', 'a b', ['secure' => true, 'partitioned' => true]);
echo json_encode(headers_list());")
        :to-equal
        "[\"Set-Cookie: chip=a+b; secure; Partitioned\"]")))
  (it-sequential
    "PHP 8.5 setcookie() option keys are case-insensitive."
    (let ((cl-cc/php::*php-http-response-code* 200)
          (cl-cc/php::*php-http-headers* nil)
          (cl-cc/php::*php-output-started-p* nil))
      (expect
        (%php-run-capture
          "<?php
setcookie('chip', 'v', ['Secure' => true, 'SameSite' => 'Strict', 'Partitioned' => true]);
echo json_encode(headers_list());")
        :to-equal
        "[\"Set-Cookie: chip=v; secure; SameSite=Strict; Partitioned\"]")))
  (it-sequential
    "PHP 8.5 setrawcookie() keeps raw values and supports partitioned cookies."
    (let ((cl-cc/php::*php-http-response-code* 200)
          (cl-cc/php::*php-http-headers* nil)
          (cl-cc/php::*php-output-started-p* nil))
      (expect
        (%php-run-capture
          "<?php
setrawcookie('raw', 'a b', ['secure' => true, 'samesite' => 'None', 'partitioned' => true]);
echo json_encode(headers_list());")
        :to-equal
        "[\"Set-Cookie: raw=a b; secure; SameSite=None; Partitioned\"]")))
  (it-sequential
    "PHP 8.5 partitioned cookies require secure cookies."
    (let ((condition
          (handler-case (progn
              (cl-cc/php::%php-setcookie
                "chip"
                "v"
                (cl-cc/php:%php-array (list t "partitioned" t)))
              nil)
            (cl-cc/php:php-exception (e)
              e))))
      (expect condition :to-be-truthy)
      (expect
        (cl-cc/php:%php-exception-matches-p condition 'value-error)
        :to-be-truthy)))
  (it-sequential
    "PHP 8.5 setcookie() rejects numeric keys, unknown keys, and invalid SameSite values."
    (flet ((raises-value-error-p (thunk)
             (let ((condition
                (handler-case (progn
                    (funcall thunk)
                    nil)
                  (cl-cc/php:php-exception (e)
                    e))))
            (and condition (cl-cc/php:%php-exception-matches-p condition 'value-error)))))
      (let ((numeric-options (cl-cc/php::%php-make-array))
            (unknown-options (cl-cc/php::%php-make-array))
            (bad-samesite-options (cl-cc/php::%php-make-array)))
        (cl-cc/php::%php-array-set numeric-options 0 t)
        (cl-cc/php::%php-array-set unknown-options "bogus" t)
        (cl-cc/php::%php-array-set bad-samesite-options "samesite" "Relaxed")
        (expect
          (raises-value-error-p
            (lambda ()
              (cl-cc/php::%php-setcookie "chip" "v" numeric-options)))
          :to-be-truthy)
        (expect
          (raises-value-error-p
            (lambda ()
              (cl-cc/php::%php-setcookie "chip" "v" unknown-options)))
          :to-be-truthy)
        (expect
          (raises-value-error-p
            (lambda ()
              (cl-cc/php::%php-setcookie "chip" "v" bad-samesite-options)))
          :to-be-truthy))))
  (it-sequential
    "PHP 8.5 session cookie params expose and emit partitioned cookies."
    (let ((cl-cc/php::*php-http-response-code* 200)
          (cl-cc/php::*php-http-headers* nil)
          (cl-cc/php::*php-output-started-p* nil)
          (cl-cc/php::*php-session-cookie-params* nil)
          (cl-cc/php::*php-session-id* "")
          (cl-cc/php::*php-session-name* "PHPSESSID")
          (cl-cc/php::*php-session-active-p* nil))
      (expect
        (%php-run-capture
          "<?php
$registered = function_exists('session_set_cookie_params') && function_exists('session_get_cookie_params') && function_exists('session_start') ? 'Y' : 'N';
session_id('12345');
session_set_cookie_params(['secure' => true, 'partitioned' => true]);
$params = session_get_cookie_params();
$partitioned = $params['partitioned'] ? 'true' : 'false';
session_start();
echo $registered . ':' . $partitioned . ':' . json_encode(headers_list());")
        :to-equal
        "Y:true:[\"Set-Cookie: PHPSESSID=12345; path=/; secure; Partitioned\"]")))
  (it-sequential
    "PHP 8.5 mail() is registered and accepts mail requests in the CLI model."
    (expect
      (%php-run-capture
        "<?php
$registered = function_exists('mail') ? 'Y' : 'N';
$result = mail('to@example.com', 'subject', 'message', ['X-Test: value'], '-f bounce@example.com');
echo $registered . ':' . ($result ? 'true' : 'false');")
      :to-equal
      "Y:true"))
  (it-sequential
    "PHP 8.5 session cookie param option keys are case-insensitive."
    (let ((cl-cc/php::*php-session-cookie-params* nil)
          (cl-cc/php::*php-session-active-p* nil))
      (expect
        (%php-run-capture
          "<?php
session_set_cookie_params(['Secure' => true, 'Partitioned' => true]);
$params = session_get_cookie_params();
echo ($params['secure'] ? 'true' : 'false') . ':' . ($params['partitioned'] ? 'true' : 'false');")
        :to-equal
        "true:true")))
  (it-sequential
    "PHP 8.5 session_get_cookie_params() inserts partitioned after secure."
    (let ((cl-cc/php::*php-session-cookie-params* nil))
      (expect
        (format
          nil
          "~{~A~^,~}"
          (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-session-get-cookie-params)))
        :to-equal
        "lifetime,path,domain,secure,partitioned,httponly,samesite")))
  (it-sequential
    "PHP 8.5 session_start() warns and fails when cookie_partitioned lacks cookie_secure."
    (let ((cl-cc/php::*php-http-response-code* 200)
          (cl-cc/php::*php-http-headers* nil)
          (cl-cc/php::*php-output-started-p* nil)
          (cl-cc/php::*php-session-cookie-params* nil)
          (cl-cc/php::*php-session-id* "")
          (cl-cc/php::*php-session-name* "PHPSESSID")
          (cl-cc/php::*php-session-active-p* nil)
          (cl-cc/php::*php-error-handler-stack* nil))
      (expect
        (%php-run-capture
          "<?php
function php85_session_warning($errno, $errstr, $file, $line) { echo $errno . ':'; return true; }
set_error_handler('php85_session_warning', E_WARNING);
session_id('12345');
session_set_cookie_params(['partitioned' => true]);
$ok = session_start();
restore_error_handler();
echo ($ok ? 'true' : 'false') . ':' . json_encode(headers_list());")
        :to-equal
        "2:false:[]")))
  )
