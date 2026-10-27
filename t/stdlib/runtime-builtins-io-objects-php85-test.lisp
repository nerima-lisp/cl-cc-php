;;;; runtime-builtins-io-objects-php85-test.lisp — src/runtime-builtins-io-objects.lisp — PHP 8.5
;;;; runtime objects.
;;;;
;;;; get_error_handler/get_exception_handler, gc_collect_cycles, the opcache probe, the persistent
;;;; cURL share handle, the Locale static methods, and which classes PHP 8.5 makes visible to
;;;; class_exists. Also touches src/runtime-builtins-io-uri.lisp and -io-compat-objects.lisp.

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 runtime objects"
  (it-sequential
    "opcache_is_script_cached_in_file_cache() is available and false without an OPCache file cache."
    (expect
      (cl-cc/php:%php-opcache-is-script-cached-in-file-cache "/tmp/example.php")
      :to-be-falsy))
  (it-sequential
    "PHP 8.5 gc_collect_cycles() returns an integer 0 in cl-cc's no-GC PHP model."
    (expect (= 0 (cl-cc/php::%php-gc-collect-cycles)) :to-be-truthy))
  (it-sequential
    "curl_share_init_persistent() returns a stable persistent handle for each ID."
    (let ((a (cl-cc/php:%php-curl-share-init-persistent "cache"))
          (b (cl-cc/php:%php-curl-share-init-persistent "cache"))
          (c (cl-cc/php:%php-curl-share-init-persistent "other")))
      (expect b :to-be a)
      (expect (eq a c) :to-be-falsy)
      (expect (gethash "__class__" a) :to-equal "CurlSharePersistentHandle")
      (expect (gethash "id" a) :to-equal "cache")
      (expect (gethash "persistent" a) :to-be-truthy)))
  (it-sequential
    "curl_multi_get_handles() exposes a multi-handle's child handles as a PHP array."
    (let* ((multi (make-hash-table :test #'equal))
           (a (make-hash-table :test #'equal))
           (b (make-hash-table :test #'equal)))
      (setf (gethash "__class__" a) "CurlHandle"
            (gethash "__class__" b) "CurlHandle"
            (gethash "handles" multi) (list a b))
      (let ((result (cl-cc/php:%php-curl-multi-get-handles multi)))
        (expect (= 2 (cl-cc/php:%php-count result)) :to-be-truthy)
        (expect (cl-cc/php:%php-array-ref result 0) :to-be a)
        (expect (cl-cc/php:%php-array-ref result 1) :to-be b))))
  (it-sequential
    "PHP 8.5 runtime-visible classes, exceptions, and enums are visible to class_exists."
    (dolist (class-name
        '("NoDiscard"
          "Closure"
          "DelayedTargetValidation"
          "CurlSharePersistentHandle"
          "Dom\\Element"
          "Dom\\HTMLCollection"
          "Dom\\HTMLDocument"
          "Filter\\FilterException"
          "Filter\\FilterFailedException"
          "IntlListFormatter"
          "Locale"
          "NumberFormatter"
          "Pdo\\Sqlite"
          "SoapClient"
          "SoapFault"
          "SoapServer"
          "Uri\\UriError"
          "Uri\\UriException"
          "Uri\\InvalidUriException"
          "Uri\\UriComparisonMode"
          "Uri\\Rfc3986\\Uri"
          "Uri\\WhatWg\\InvalidUrlException"
          "Uri\\WhatWg\\UrlValidationErrorType"
          "Uri\\WhatWg\\UrlValidationError"
          "Uri\\WhatWg\\Url"
          "XSLTProcessor"))
      (expect (cl-cc/php::%php-class-exists class-name) :to-be-truthy)))
  (it-sequential
    "PHP 8.5 class_alias registers aliases for runtime-visible classes."
    (let ((alias (format nil "Php85AliasRuntimeUri~A" (symbol-name (gensym)))))
      (expect (cl-cc/php::%php-class-alias "Uri\\Rfc3986\\Uri" alias) :to-be-truthy)
      (expect (cl-cc/php::%php-class-exists alias) :to-be-truthy)
      (expect (cl-cc/php::%php-method-exists alias "parse") :to-be-truthy)
      (let ((methods
            (cl-cc/php::%php-array-values-list (cl-cc/php::%php-get-class-methods alias))))
        (expect (find "toRawString" methods :test #'string=) :to-be-truthy))))
  (it-sequential
    "PHP 8.5 class_alias rejects array and callable aliases."
    (dolist (alias '("array" "callable" "ARRAY" "Callable"))
      (let ((condition
            (handler-case (progn
                (cl-cc/php::%php-class-alias "Uri\\Rfc3986\\Uri" alias)
                nil)
              (cl-cc/php:php-exception (e)
                e))))
        (expect condition :to-be-truthy)
        (expect
          (cl-cc/php:%php-exception-matches-p condition 'value-error)
          :to-be-truthy))))
  (it-sequential
    "PHP 8.5 built-in class method additions are visible to method_exists."
    (dolist (case '(("Dom\\Element" "getElementsByClassName")
          ("Dom\\Element" "insertAdjacentHTML")
          ("Dom\\HTMLDocument" "getElementsByName")
          ("Closure" "getCurrent")
          ("Locale" "addLikelySubtags")
          ("Locale" "isRightToLeft")
          ("Locale" "minimizeSubtags")
          ("Pdo\\Sqlite" "setAuthorizer")
          ("SoapClient" "__construct")
          ("SoapClient" "__getTypes")
          ("SoapFault" "__construct")
          ("SoapServer" "__construct")
          ("SoapServer" "fault")
          ("XSLTProcessor" "__construct")
          ("XSLTProcessor" "getParameter")
          ("XSLTProcessor" "setParameter")
          ("XSLTProcessor" "removeParameter")
          ("SQLite3Stmt" "busy")
          ("ReflectionConstant" "getFileName")
          ("ReflectionConstant" "getExtension")
          ("ReflectionConstant" "getExtensionName")
          ("ReflectionConstant" "getAttributes")
          ("ReflectionConstant" "isDeprecated")
          ("ReflectionProperty" "getMangledName")
          ("Uri\\Rfc3986\\Uri" "parse")
          ("Uri\\Rfc3986\\Uri" "withUserInfo")
          ("Uri\\WhatWg\\Url" "toAsciiString")
          ("Uri\\WhatWg\\Url" "withUsername")
          ("Uri\\WhatWg\\UrlValidationError" "__construct")))
      (destructuring-bind (class method) case
        (expect (cl-cc/php::%php-method-exists class method) :to-be-truthy))))
  (it-sequential
    "PHP 8.5 predefined constants are available through constant lookup."
    (dolist (constant
        '("PHP_BUILD_DATE"
          "PHP_BUILD_PROVIDER"
          "CURLINFO_USED_PROXY"
          "CURLINFO_HTTPAUTH_USED"
          "CURLINFO_PROXYAUTH_USED"
          "CURLINFO_CONN_ID"
          "CURLINFO_QUEUE_TIME_T"
          "CURLOPT_INFILESIZE_LARGE"
          "CURLOPT_SSL_SIGNATURE_ALGORITHMS"
          "CURLFOLLOW_ALL"
          "CURLFOLLOW_OBEYCODE"
          "CURLFOLLOW_FIRSTONLY"
          "FILTER_THROW_ON_FAILURE"
          "DECIMAL_COMPACT_SHORT"
          "DECIMAL_COMPACT_LONG"
          "OPENSSL_PKCS1_PSS_PADDING"
          "PKCS7_NOSMIMECAP"
          "PKCS7_CRLFEOL"
          "PKCS7_NOCRL"
          "PKCS7_NO_DUAL_CONTENT"
          "POSIX_SC_OPEN_MAX"
          "IPPROTO_ICMP"
          "IPPROTO_ICMPV6"
          "TCP_FUNCTION_BLK"
          "TCP_FUNCTION_ALIAS"
          "TCP_REUSPORT_LB_NUMA"
          "TCP_REUSPORT_LB_NUMA_NODOM"
          "TCP_REUSPORT_LB_NUMA_CURDOM"
          "TCP_BBR_ALGORITHM"
          "AF_PACKET"
          "IP_BINDANY"
          "SO_BUSY_POLL"
          "UDP_SEGMENT"
          "SHUT_RD"
          "SHUT_WR"
          "SHUT_RDWR"
          "TOKEN_PARSE"
          "T_LNUMBER"
          "T_DNUMBER"
          "T_STRING"
          "T_VARIABLE"
          "T_CONSTANT_ENCAPSED_STRING"
          "T_OBJECT_OPERATOR"
          "T_DOUBLE_ARROW"
          "T_COMMENT"
          "T_DOC_COMMENT"
          "T_OPEN_TAG"
          "T_OPEN_TAG_WITH_ECHO"
          "T_CLOSE_TAG"
          "T_WHITESPACE"
          "T_DOUBLE_COLON"
          "T_VOID_CAST"
          "T_PIPE"
          "T_INLINE_HTML"
          "T_ECHO"
          "T_CLASS"
          "T_CONST"
          "T_PUBLIC"
          "T_FUNCTION"
          "T_ABSTRACT"
          "T_ARRAY"
          "T_AS"
          "T_BREAK"
          "T_CALLABLE"
          "T_CASE"
          "T_CATCH"
          "T_CLONE"
          "T_CONTINUE"
          "T_DECLARE"
          "T_DEFAULT"
          "T_DO"
          "T_ELSE"
          "T_ELSEIF"
          "T_EMPTY"
          "T_ENDDECLARE"
          "T_ENDFOR"
          "T_ENDFOREACH"
          "T_ENDIF"
          "T_ENDSWITCH"
          "T_ENDWHILE"
          "T_ENUM"
          "T_EVAL"
          "T_EXIT"
          "T_EXTENDS"
          "T_FINAL"
          "T_FINALLY"
          "T_FN"
          "T_FOR"
          "T_FOREACH"
          "T_GLOBAL"
          "T_GOTO"
          "T_IF"
          "T_IMPLEMENTS"
          "T_INCLUDE"
          "T_INCLUDE_ONCE"
          "T_INSTANCEOF"
          "T_INSTEADOF"
          "T_INTERFACE"
          "T_ISSET"
          "T_LIST"
          "T_MATCH"
          "T_NAMESPACE"
          "T_NEW"
          "T_PRINT"
          "T_PRIVATE"
          "T_PROTECTED"
          "T_READONLY"
          "T_REQUIRE"
          "T_REQUIRE_ONCE"
          "T_RETURN"
          "T_STATIC"
          "T_SWITCH"
          "T_THROW"
          "T_TRAIT"
          "T_TRY"
          "T_UNSET"
          "T_USE"
          "T_VAR"
          "T_WHILE"
          "T_YIELD"
          "T_LOGICAL_AND"
          "T_LOGICAL_OR"
          "T_LOGICAL_XOR"
          "T_YIELD_FROM"
          "T_ATTRIBUTE"
          "T_NS_SEPARATOR"
          "T_NAME_FULLY_QUALIFIED"
          "T_NAME_QUALIFIED"
          "T_NAME_RELATIVE"
          "T_BAD_CHARACTER"
          "IMAGETYPE_UNKNOWN"
          "IMAGETYPE_WEBP"
          "IMAGETYPE_AVIF"
          "IMAGETYPE_HEIF"
          "IMAGETYPE_SVG"
          "IMAGETYPE_COUNT"))
      (multiple-value-bind (value found) (cl-cc/php::%php-lookup-constant constant)
        (declare (ignore value))
        (expect found :to-be-truthy)))))
