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
    "PHP 8.5 session_get_cookie_params() inserts partitioned after secure."
    (let ((cl-cc/php::*php-session-cookie-params* nil))
      (expect
        (format
          nil
          "~{~A~^,~}"
          (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-session-get-cookie-params)))
        :to-equal
        "lifetime,path,domain,secure,partitioned,httponly,samesite")))
  )
