;;;; runtime-builtins-io-uri-php85-test.lisp — src/runtime-builtins-io-uri.lisp — the PHP 8.5 URI
;;;; classes (Uri\Rfc3986\Uri, Uri\WhatWg\Url, and their comparison/exception types).
;;;;
;;;; Split out of runtime-builtins-io-objects-php85-test.lisp, which stayed over the 500-line
;;;; limit even after the split: these nine tests are the ones that exercise the URI classes
;;;; specifically, rather than the broader "PHP 8.5 runtime objects" grab-bag the parent file
;;;; covers.

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 URI classes"
  (it-sequential
    "PHP 8.5 URI class methods are listed for runtime class-name introspection."
    (let ((methods
          (cl-cc/php::%php-array-values-list
            (cl-cc/php::%php-get-class-methods "Uri\\Rfc3986\\Uri"))))
      (expect (find "toRawString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUserInfo" methods :test #'string=) :to-be-truthy))
    (let ((methods
          (cl-cc/php::%php-array-values-list
            (cl-cc/php::%php-get-class-methods "Uri\\WhatWg\\Url"))))
      (expect (find "toAsciiString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUsername" methods :test #'string=) :to-be-truthy)))
  (it-sequential
    "PHP 8.5 URI objects expose parsed components and with* cloning."
    (let* ((uri (cl-cc/php::%php-uri-rfc3986-new "https://user:pw@example.com/a?b=1#frag"))
           (copy (cl-cc/php::%php-uri-with-user-info uri "ada")))
      (expect (cl-cc/php::%php-uri-get-scheme uri) :to-equal "https")
      (expect (cl-cc/php::%php-uri-get-host uri) :to-equal "example.com")
      (expect (cl-cc/php::%php-uri-get-path uri) :to-equal "/a")
      (expect (cl-cc/php::%php-uri-get-query uri) :to-equal "b=1")
      (expect (cl-cc/php::%php-uri-get-fragment uri) :to-equal "frag")
      (expect (cl-cc/php::%php-uri-get-username uri) :to-equal "user")
      (expect (cl-cc/php::%php-uri-get-username copy) :to-equal "ada")
      (expect (cl-cc/php::%php-uri-get-username uri) :to-equal "user")))
  (it-sequential
    "PHP 8.5 URI parse helpers return null instead of throwing on invalid input."
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-uri-rfc3986-parse "https://example.com/%zz"))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-uri-rfc3986-parse "http://example.com:99999/"))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-null-p (cl-cc/php::%php-uri-whatwg-parse "/relative-only"))
      :to-be-truthy)
    (let ((base (cl-cc/php::%php-uri-whatwg-new "https://example.com/root")))
      (expect
        (cl-cc/php::%php-uri-get-path (cl-cc/php::%php-uri-whatwg-parse "/child" base))
        :to-equal
        "/child")))
  (it-sequential
    "PHP 8.5 URI constructors throw the documented URI exception classes on invalid input."
    (let ((condition
          (handler-case (progn
              (cl-cc/php::%php-uri-rfc3986-new "https://example.com/%zz")
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
              (cl-cc/php::%php-uri-whatwg-new "/relative-only")
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
    "PHP 8.5 URI equality excludes fragments by default and includes them with UriComparisonMode::IncludeFragment."
    (let ((a (cl-cc/php::%php-uri-rfc3986-new "https://example.com/a#one"))
          (b (cl-cc/php::%php-uri-rfc3986-new "https://example.com/a#two")))
      (expect (cl-cc/php::%php-uri-equals a b) :to-be-truthy)
      (expect
        (cl-cc/php::%php-uri-equals
          a
          b
          (cl-cc/php:%php-predefined-class-constant
            "Uri\\UriComparisonMode"
            "IncludeFragment"))
        :to-be-falsy))
    (expect
      (%php-run-capture
        "<?php
$a = new Uri\\Rfc3986\\Uri('https://example.com/a#one');
$b = new Uri\\Rfc3986\\Uri('https://example.com/a#two');
echo ($a->equals($b) ? 'Y' : 'N') . ':' . ($a->equals($b, Uri\\UriComparisonMode::IncludeFragment) ? 'Y' : 'N');
")
      :to-equal
      "Y:N"))
  (it-sequential
    "PHP 8.5 method introspection accepts runtime objects."
    (let* ((uri (cl-cc/php::%php-uri-rfc3986-new "https://example.com/"))
           (methods
          (cl-cc/php::%php-array-values-list (cl-cc/php::%php-get-class-methods uri))))
      (expect (find "toRawString" methods :test #'string=) :to-be-truthy)
      (expect (find "withUserInfo" methods :test #'string=) :to-be-truthy)))
  (it-sequential
    "PHP 8.5 object debug output uses __debugInfo for Uri objects."
    (expect
      (%php-run-capture
        "<?php
$u = new Uri\\Rfc3986\\Uri('https://user@example.com/a?b=1#frag');
var_dump($u);
")
      :to-equal
      "object(Uri\\Rfc3986\\Uri) (8) {
  [\"scheme\"]=>
  string(5) \"https\"
  [\"username\"]=>
  string(4) \"user\"
  [\"password\"]=>
  NULL
  [\"host\"]=>
  string(11) \"example.com\"
  [\"port\"]=>
  NULL
  [\"path\"]=>
  string(2) \"/a\"
  [\"query\"]=>
  string(3) \"b=1\"
  [\"fragment\"]=>
  string(4) \"frag\"
}")
    (expect
      (%php-run-capture
        "<?php
$u = new Uri\\Rfc3986\\Uri('https://user@example.com/a?b=1#frag');
echo print_r($u, true);
")
      :to-equal
      "Uri\\Rfc3986\\Uri Object (
    [scheme] => https
    [username] => user
    [password] => NULL
    [host] => example.com
    [port] => NULL
    [path] => /a
    [query] => b=1
    [fragment] => frag
)"))
  (it-sequential
    "PHP 8.5 URI constructor and static parse helpers execute from PHP source."
    (expect
      (%php-run-capture
        "<?php
$u = new Uri\\Rfc3986\\Uri('https://user@example.com/a?b=1#frag');
$v = $u->withUserInfo('ada');
$w = Uri\\WhatWg\\Url::parse('https://example.com/p');
echo $u->getScheme() . ':' . $u->getHost() . ':' . $u->getPath() . ':' . $u->getQuery() . ':' . $u->getFragment() . ':' . $u->getUsername() . ':' . $v->getUsername() . ':' . $w->toAsciiString();
")
      :to-equal
      "https:example.com:/a:b=1:frag:user:ada:https://example.com/p"))
  )
