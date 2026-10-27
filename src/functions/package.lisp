(defpackage #:cl-cc/php/functions
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-call-args
                #:ast-call-func
                #:ast-call-p
                #:ast-children
                #:ast-defun
                #:ast-lambda
                #:ast-lambda-body
                #:ast-lambda-declarations
                #:ast-lambda-env
                #:ast-lambda-key-params
                #:ast-lambda-optional-params
                #:ast-lambda-p
                #:ast-lambda-params
                #:ast-lambda-rest-param
                #:ast-let-bindings
                #:ast-let-body
                #:ast-let-declarations
                #:ast-let-p
                #:ast-list-elements
                #:ast-list-p
                #:ast-quote-p
                #:ast-quote-value
                #:ast-var-name
                #:ast-var-p
                #:make-ast-apply
                #:make-ast-block
                #:make-ast-call
                #:make-ast-defun
                #:make-ast-int
                #:make-ast-lambda
                #:make-ast-let
                #:make-ast-quote
                #:make-ast-setq
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/arrays
                #:%php-array
                #:%php-array-call
                #:%php-array-entry
                #:%php-array-ref
                #:%php-array-values-list
                #:%php-count
                #:%php-list-to-array
                #:%php-spread
                #:register-php-array-callable-resolver
  )
  (:import-from #:cl-cc/php/attributes
                #:%php-attribute-metadata
                #:%php-parse-attributes
  )
  (:import-from #:cl-cc/php/errors
                #:%php-throw
                #:register-php-error-callable-resolver
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-first-class-callable
                #:%php-call
                #:%php-lower-reference-assignments
                #:%php-null-quote
                #:%php-param-name
                #:%php-rewrite-ref-vars
                #:php-parse-arglist
                #:php-parse-expr)
  (:import-from #:cl-cc/php/statements
                #:php-cst-parse-block
                #:php-parse-block
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-consume-expected
                #:%php-cst-interior
                #:%PARSER-PHP-CST-PARSE-OPAQUE-KEYWORD-EXPRESSION
                #:%php-helper-call-p
                #:%php-name-absolute-p
                #:%php-reference-token-p
                #:%PARSER-PHP-RUNTIME-SYMBOL
                #:%php-strip-leading-namespace-separator
                #:%php-tok-to-cst
                #:*php-current-namespace*
                #:define-php-stmt-parser
                #:php-consume
                #:php-cst-parse-expr
                #:php-expect
                #:php-ident-sym
                #:php-peek-type
                #:php-peek-value
                #:php-resolve-qualified-name
                #:php-skip-semis
                #:php-tok-value
                #:php-ts-advance
                #:php-ts-at-type-p
                #:php-ts-expect
                #:php-ts-peek-type
                #:php-ts-peek-value
                #:php-var-sym
                #:register-php-cst-keyword-expression-parser
                #:register-php-cst-keyword-statement-parser
                #:register-php-expression-callable-resolver
                #:register-php-expression-dynamic-call-lowerer
                #:register-php-expression-function-call-parser
                #:register-php-expression-keyword-parser
                #:register-php-expression-method-call-lowerer
                #:register-php-expression-static-member-lowerer
                #:register-php-runtime-symbol
                #:register-php-source-finalizer
                #:register-php-source-state-initializer
  )
  (:import-from #:cl-cc/php/types
                #:%php-deref
                #:%php-make-ref
                #:php-parse-type-annotation
  )
  (:export
   #:%php-callable-body
   #:%php-callable-function
   #:%php-callable-ref
   #:%php-current-closure
   #:%php-first-class-callable-p
   #:%PHP-LOOKUP-BUILTIN-SYMBOL
   #:%php-member-slot-allocation
   #:%php-named-args-to-positional
   #:%php-seed-by-ref-param-registry
   #:*php-by-ref-param-registry*
   #:*php-named-param-registry*
   #:php-parse-param-list
   #:php-parse-return-type
   #:register-php-builtin-function-resolver
   #:register-php-builtin-symbol-resolver
   #:register-php-parameter-modifier-parser)
)
(in-package #:cl-cc/php/functions)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

