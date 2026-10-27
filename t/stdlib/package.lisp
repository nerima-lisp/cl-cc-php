(defpackage :cl-cc/php/stdlib/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php
                #:%php-array #:%php-array-ref #:%php-count #:%php-curl-multi-get-handles
                #:%php-curl-share-init-persistent #:%php-enchant-dict-remove #:%php-exception-matches-p #:%php-filter-var
                #:%php-locale-is-right-to-left #:%php-opcache-is-script-cached-in-file-cache #:%php-pg-close-stmt #:%php-pg-service
                #:%php-predefined-class-constant #:parse-php-source #:php-exception)
  (:import-from :cl-cc/php/arrays
                #:%php-array #:%php-array-ref #:%php-array-set #:%php-count #:%php-make-array
                #:%php-array-ordered-keys
                #:%php-array-values-list
                #:%php-list-to-array)
  (:import-from :cl-cc/php/errors
                #:%php-exception-class #:%php-exception-matches-p #:php-exception
                #:*php-error-handler-stack* #:*php-error-reporting-level*
                #:*php-exception-handler-stack*)
  (:import-from :cl-cc/php/stdlib
                #:%php-abs #:%php-array-map-keys
                #:%php-atan2 #:%php-avif-bytes-p #:%php-base-convert #:%php-basename
                #:%php-bcadd #:%php-bccomp #:%php-bcdiv #:%php-bcmod
                #:%php-bcmul #:%php-bcpow #:%php-bcscale #:%php-bcsqrt
                #:%php-bcsub #:%php-bindec #:%php-bytes-ascii-string #:%php-bytes-match-string-p
                #:%php-bytes-prefix-p #:%php-ceil #:%php-checkdate #:%php-class-alias
                #:%php-class-exists #:%php-class-implements #:%php-class-parents #:%php-class-uses
                #:%php-compile-regex #:%php-cookie-bool #:%php-cookie-expires-gmt #:%php-cookie-integer
                #:%php-cookie-month-name #:%php-cookie-samesite #:%php-cookie-string #:%php-cookie-weekday-name
                #:%php-copy #:%php-cos #:%php-curl-multi-get-handles #:%php-curl-share-init-persistent
                #:%php-current #:%php-date-create #:%php-date-default-timezone-get #:%php-date-default-timezone-set
                #:%php-date-diff #:%php-date-format #:%php-date-modify #:%php-date-timestamp
                #:%php-days-in-month #:%php-decbin #:%php-dechex #:%php-decoct
                #:%php-defined-class-symbol-p #:%php-deg2rad #:%php-detect-image-type #:%php-dirname
                #:%php-dom-element-new #:%php-dom-html-document-get-elements-by-name #:%php-dom-html-document-new #:%php-enchant-dict-remove
                #:%php-end #:%php-error-reporting #:%php-exif-imagetype #:%php-fclose
                #:%php-fdiv #:%php-feof #:%php-fflush #:%php-fgetc
                #:%php-fgetcsv #:%php-fgets #:%php-file #:%php-file-exists
                #:%php-file-get-contents #:%php-file-put-contents #:%php-filesize #:%php-filetype
                #:%php-filter-var #:%php-flock #:%php-floor #:%php-fmod
                #:%php-fopen #:%php-fputcsv #:%php-fread #:%php-fseek
                #:%php-ftell #:%php-function-exists #:%php-fwrite #:%php-gc-collect-cycles
                #:%php-get-class #:%php-get-class-methods #:%php-get-error-handler #:%php-get-exception-handler
                #:%php-get-object-vars #:%php-get-parent-class #:%php-getenv #:%php-getimagesize
                #:%php-gif-dimensions #:%php-gmp-abs #:%php-gmp-add #:%php-gmp-cmp
                #:%php-gmp-div-q #:%php-gmp-fact #:%php-gmp-gcd #:%php-gmp-init
                #:%php-gmp-intval #:%php-gmp-mod #:%php-gmp-mul #:%php-gmp-neg
                #:%php-gmp-num #:%php-gmp-pow #:%php-gmp-sqrt #:%php-gmp-strval
                #:%php-gmp-sub #:%php-heif-bytes-p #:%php-hexdec #:%php-http-build-query
                #:%php-hypot #:%php-image-dimensions-and-units #:%php-image-type-from-bytes #:%php-image-type-info
                #:%php-image-type-to-extension #:%php-image-type-to-mime-type #:%php-ini-get #:%php-ini-set
                #:%php-instanceof #:%php-intdiv #:%php-interface-exists #:%php-is-a
                #:%php-is-dir #:%php-is-executable #:%php-is-file #:%php-is-finite
                #:%php-is-infinite #:%php-is-link #:%php-is-nan #:%php-is-readable
                #:%php-is-writable #:%php-iterator-count #:%php-iterator-to-array #:%php-jpeg-dimensions
                #:%php-jpeg-sof-marker-p #:%php-json-decode #:%php-json-encode #:%php-json-quote-string
                #:%php-json-validate #:%php-key #:%php-lcg-value #:%php-leap-year-p
                #:%php-list-assign #:%php-locale-add-likely-subtags #:%php-locale-is-right-to-left
                #:%php-locale-minimize-subtags #:%php-locale-normalized-id #:%php-locale-subtags #:%php-log
                #:%php-log10 #:%php-log2 #:%php-lookup-constant #:%php-lookup-dynamic-constant
                #:%php-max #:%php-memory-limit-exceeds-p #:%php-memory-limit-unit-multiplier #:%php-method-exists
                #:%php-method-table-methods #:%php-microtime-float #:%php-min #:%php-mkdir
                #:%php-mt-rand #:%php-mt-srand #:%php-next #:%php-octdec
                #:%php-opcache-is-script-cached-in-file-cache #:%php-parse-memory-limit #:%php-parse-str
                #:%php-path-string #:%php-pathinfo #:%php-pg-close-stmt #:%php-pg-service
                #:%php-php-float-epsilon #:%php-php-float-max #:%php-php-int-max #:%php-php-int-min
                #:%php-php-int-size #:%php-php-sapi-name #:%php-php-uname #:%php-php-version
                #:%php-pi #:%php-png-dimensions #:%php-pow #:%php-predefined-class-constant
                #:%php-preg-match #:%php-preg-match-all #:%php-preg-match-all-matches #:%php-preg-match-matches
                #:%php-preg-quote #:%php-preg-replace #:%php-preg-split #:%php-prev
                #:%php-property-exists #:%php-putenv #:%php-rad2deg #:%php-rand
                #:%php-random-bytes #:%php-random-int #:%php-realpath #:%php-reflection-class-descriptor-p
                #:%php-reflection-class-symbol #:%php-reflection-class-symbol-from-name #:%php-reflection-class-trait-symbols #:%php-reflection-interface-p
                #:%php-reflection-symbol-name #:%php-reflection-symbols-to-array #:%php-reflection-unique-symbols #:%php-regex-group-string
                #:%php-regex-match-at #:%php-register-runtime-class-methods #:%php-register-runtime-class-tag #:%php-register-runtime-interface-tag
                #:%php-rename #:%php-reset #:%php-restore-error-handler #:%php-restore-exception-handler
                #:%php-rewind #:%php-round #:%php-runtime-class-alias-name-forbidden-p #:%php-runtime-class-canonical-key
                #:%php-runtime-class-method-exists-p #:%php-runtime-class-methods #:%php-runtime-class-tag-exists-p #:%php-runtime-interface-tag-exists-p
                #:%php-runtime-type-key #:%php-scandir #:%php-session-apply-start-options #:%php-session-get-cookie-params
                #:%php-set-error-handler #:%php-set-exception-handler #:%php-setcookie #:%php-settype
                #:%php-settype-array-value #:%php-settype-object-value #:%php-sin #:%php-skip-xml-space
                #:%php-sleep #:%php-spl-autoload-callback-valid-p #:%php-spl-autoload-functions #:%php-spl-autoload-register
                #:%php-spl-autoload-unregister #:%php-sqrt #:%php-srand #:%php-stderr
                #:%php-stdin #:%php-stdout #:%php-strip-pattern #:%php-svg-attribute-value
                #:%php-svg-dimension #:%php-svg-dimensions #:%php-svg-name-char-p #:%php-svg-number-value
                #:%php-svg-start-tag #:%php-svg-text-p #:%php-sys-get-temp-dir #:%php-tan
                #:%php-tempnam #:%php-timezone-name #:%php-timezone-offset-seconds #:%php-token-get-all
                #:%php-token-name #:%php-u16-be #:%php-u16-le #:%php-u32-be
                #:%php-unlink #:%php-uri-get-fragment #:%php-uri-get-host #:%php-uri-get-path
                #:%php-uri-get-query #:%php-uri-get-scheme #:%php-uri-get-username #:%php-uri-rfc3986-new
                #:%php-uri-rfc3986-parse #:%php-uri-whatwg-new #:%php-uri-whatwg-parse #:%php-uri-with-user-info
                #:%php-usleep #:%php-webp-bytes-p #:%php-xml-space-p #:*php-predefined-class-constants* #:*php-predefined-constants*
                #:*php-session-cookie-params* #:*php-session-name* #:*php-spl-autoload-functions* #:division-by-zero-error)
  (:import-from :cl-cc/php/types
                #:%php-null-p #:+php-null+ #:%php-deref #:%php-make-ref
                #:%php-parse-integer-setting)
  (:import-from :cl-cc/ast
                #:ast-call-p #:ast-let-bindings)
  (:import-from :cl-cc/php/syntax/test
                #:%php-call-name #:%php-first)
  (:import-from :cl-cc/php/syntax
                #:parse-php-source)
)

