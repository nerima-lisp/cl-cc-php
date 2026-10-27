(defpackage #:cl-cc/php/syntax
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-call-args #:ast-call-func #:ast-call-p
                #:ast-children #:ast-defclass-p #:ast-defclass-php-kind
                #:ast-error #:ast-imports #:ast-namespace
                #:ast-node #:ast-node-p #:ast-quote-p #:ast-quote-value
                #:ast-var-name #:ast-var-p)
  (:import-from #:cl-cc/bootstrap
                #:make-cst-token)
  (:import-from #:cl-cc/parse
                #:def-grammar-rule #:make-cst-interior #:make-parse-error)
  (:export
   #:register-php-expression-constant-resolvers
   #:%php-consume-expected
   #:%php-cst-interior
   #:%PARSER-PHP-CST-PARSE-OPAQUE-KEYWORD-EXPRESSION
   #:%PARSER-PHP-CST-PARSE-UNARY-KEYWORD-EXPRESSION
   #:%php-helper-call-p
   #:%php-keyword-p
   #:%php-name-absolute-p
   #:%php-named-arg-p
   #:%php-qualified-name-segment-string
   #:%php-reference-token-p
   #:%PARSER-PHP-RUNTIME-SYMBOL
   #:%php-strip-leading-namespace-separator
   #:%php-tok-to-cst
   #:%php-unsupported
   #:*php-current-imports*
   #:*php-current-namespace*
   #:*php-expression-constant-resolver*
   #:*php-expression-dynamic-call-lowerer*
   #:*php-expression-dynamic-constant-resolver*
   #:*php-expression-function-call-parser*
   #:*php-expression-keyword-parsers*
   #:*php-expression-method-call-lowerer*
   #:*php-expression-primary-parsers*
   #:*php-keyword-statement-parsers*
   #:*php-pending-top-level-forms*
   #:*php-statement-attribute-attacher*
   #:*php-statement-attribute-parser*
   #:*php-stmt-parsers*
   #:call-php-array-expression-lowerer
   #:call-php-expression-callable-resolver
   #:call-php-expression-static-member-lowerers
   #:define-php-stmt-parser
   #:make-php-token-stream
   #:parse-php-source
   #:parse-php-source-to-cst
   #:php-annotate-top-level-node
   #:php-at-eof-p
   #:php-check-supported-forms
   #:php-consume
   #:php-cst-parse-arglist
   #:php-cst-parse-expr
   #:php-expect
   #:php-ident-sym
   #:php-parse-qualified-name
   #:php-peek
   #:php-peek-type
   #:php-peek-value
   #:php-resolve-qualified-name
   #:php-skip-semis
   #:php-tok-type
   #:php-tok-value
   #:php-token-stream-tokens
   #:php-ts-advance
   #:php-ts-at-end-p
   #:php-ts-at-type-p
   #:php-ts-at-value-p
   #:php-ts-expect
   #:php-ts-peek-type
   #:php-ts-peek-value
   #:php-ts-skip-semis
   #:php-var-sym
   #:register-php-array-expression-lowerer
   #:register-php-cst-keyword-expression-parser
   #:register-php-cst-keyword-statement-parser
   #:register-php-cst-primary-parser
   #:register-php-cst-statement-parser
   #:register-php-expression-callable-resolver
   #:register-php-expression-dynamic-call-lowerer
   #:register-php-expression-function-call-parser
   #:register-php-expression-keyword-parser
   #:register-php-expression-method-call-lowerer
   #:register-php-expression-primary-parser
   #:register-php-expression-static-member-lowerer
   #:register-php-runtime-package
   #:register-php-runtime-symbol
   #:register-php-source-finalizer
   #:register-php-source-state-initializer
   #:register-php-source-statement-parser
   #:register-php-statement-attribute-attacher
   #:register-php-statement-attribute-parser
   #:tokenize-php-source))
