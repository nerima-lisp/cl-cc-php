(in-package :cl-cc/php/stdlib/test)

(describe "PHP standard library tests"
  (it-sequential
    "PHP 8.5 Locale direction helper detects common RTL locale identifiers."
    (expect (cl-cc/php:%php-locale-is-right-to-left "ar_EG.UTF-8") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "fa-IR") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "az-Arab") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "en_US") :to-be-falsy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "az-Latn") :to-be-falsy))
  (it-sequential
    "PHP_BUILD_DATE and PHP_BUILD_PROVIDER resolve as predefined PHP 8.5 constants."
    (multiple-value-bind (date date-found) (cl-cc/php/stdlib:%php-lookup-constant "PHP_BUILD_DATE")
      (multiple-value-bind (provider provider-found) (cl-cc/php/stdlib:%php-lookup-constant "PHP_BUILD_PROVIDER")
        (expect date-found :to-be-truthy)
        (expect provider-found :to-be-truthy)
        (expect date :to-equal "1970-01-01T00:00:00+00:00")
        (expect provider :to-equal "cl-cc")))))
