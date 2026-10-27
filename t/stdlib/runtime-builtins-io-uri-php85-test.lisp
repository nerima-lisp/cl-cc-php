;;;; runtime-builtins-io-uri-php85-test.lisp — src/runtime-builtins-io-uri.lisp — the PHP 8.5 URI
;;;; classes (Uri\Rfc3986\Uri, Uri\WhatWg\Url, and their comparison/exception types).
;;;;
;;;; Split out of runtime-builtins-io-objects-php85-test.lisp, which stayed over the 500-line
;;;; limit even after the split: these nine tests are the ones that exercise the URI classes
;;;; specifically, rather than the broader "PHP 8.5 runtime objects" grab-bag the parent file
;;;; covers.

(in-package :cl-cc/php/stdlib/test)

(describe
  "PHP 8.5 URI classes"
  (it-sequential
    "PHP 8.5 URI class methods are listed for runtime class-name introspection."
    (let ((methods
          (cl-cc/php/arrays:%php-array-values-list
            (cl-cc/php/stdlib:%php-get-class-methods "Uri\\Rfc3986\\Uri"))))
      (expect (find "toRawString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUserInfo" methods :test #'string=) :to-be-truthy))
    (let ((methods
          (cl-cc/php/arrays:%php-array-values-list
            (cl-cc/php/stdlib:%php-get-class-methods "Uri\\WhatWg\\Url"))))
      (expect (find "toAsciiString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUsername" methods :test #'string=) :to-be-truthy)))
  (it-sequential
    "PHP 8.5 URI objects expose parsed components and with* cloning."
    (let* ((uri (cl-cc/php/stdlib:%php-uri-rfc3986-new "https://user:pw@example.com/a?b=1#frag"))
           (copy (cl-cc/php/stdlib:%php-uri-with-user-info uri "ada")))
      (expect (cl-cc/php/stdlib:%php-uri-get-scheme uri) :to-equal "https")
      (expect (cl-cc/php/stdlib:%php-uri-get-host uri) :to-equal "example.com")
      (expect (cl-cc/php/stdlib:%php-uri-get-path uri) :to-equal "/a")
      (expect (cl-cc/php/stdlib:%php-uri-get-query uri) :to-equal "b=1")
      (expect (cl-cc/php/stdlib:%php-uri-get-fragment uri) :to-equal "frag")
      (expect (cl-cc/php/stdlib:%php-uri-get-username uri) :to-equal "user")
      (expect (cl-cc/php/stdlib:%php-uri-get-username copy) :to-equal "ada")
      (expect (cl-cc/php/stdlib:%php-uri-get-username uri) :to-equal "user")))
  (it-sequential
    "PHP 8.5 URI parse helpers return null instead of throwing on invalid input."
    (expect
      (cl-cc/php:%php-null-p
        (cl-cc/php/stdlib:%php-uri-rfc3986-parse "https://example.com/%zz"))
      :to-be-truthy)
    (expect
      (cl-cc/php:%php-null-p
        (cl-cc/php/stdlib:%php-uri-rfc3986-parse "http://example.com:99999/"))
      :to-be-truthy)
    (expect
      (cl-cc/php:%php-null-p (cl-cc/php/stdlib:%php-uri-whatwg-parse "/relative-only"))
      :to-be-truthy)
    (let ((base (cl-cc/php/stdlib:%php-uri-whatwg-new "https://example.com/root")))
      (expect
        (cl-cc/php/stdlib:%php-uri-get-path (cl-cc/php/stdlib:%php-uri-whatwg-parse "/child" base))
        :to-equal
        "/child")))
  (it-sequential
    "PHP 8.5 URI constructors throw the documented URI exception classes on invalid input."
    (let ((condition
          (handler-case (progn
              (cl-cc/php/stdlib:%php-uri-rfc3986-new "https://example.com/%zz")
              nil)
            (cl-cc/php:php-exception (e)
              e))))
      (expect condition :to-be-truthy)
      (expect
        (cl-cc/php:%php-exception-matches-p
          condition
          (intern "URI\\INVALIDURIEXCEPTION" :cl-cc/php))
        :to-be-truthy))
    (let ((condition
          (handler-case (progn
              (cl-cc/php/stdlib:%php-uri-whatwg-new "/relative-only")
              nil)
            (cl-cc/php:php-exception (e)
              e))))
      (expect condition :to-be-truthy)
      (expect
        (cl-cc/php:%php-exception-matches-p
          condition
          (intern "URI\\WHATWG\\INVALIDURLEXCEPTION" :cl-cc/php))
        :to-be-truthy)))
  (it-sequential
    "PHP 8.5 method introspection accepts runtime objects."
    (let* ((uri (cl-cc/php/stdlib:%php-uri-rfc3986-new "https://example.com/"))
           (methods
          (cl-cc/php/arrays:%php-array-values-list (cl-cc/php/stdlib:%php-get-class-methods uri))))
      (expect (find "toRawString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUserInfo" methods :test #'string=) :to-be-truthy)))
  )
