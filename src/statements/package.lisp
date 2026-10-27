(defpackage #:cl-cc/php/statements
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-call-args
                #:ast-let-body
                #:ast-let-p
                #:ast-progn-p
                #:ast-slot-value-object
                #:ast-slot-value-p
                #:ast-slot-value-slot
                #:ast-var-name
                #:ast-var-p
                #:make-ast-block
                #:make-ast-call
                #:make-ast-catch
                #:make-ast-defvar
                #:make-ast-go
                #:make-ast-if
                #:make-ast-int
                #:make-ast-lambda
                #:make-ast-let
                #:make-ast-progn
                #:make-ast-quote
                #:make-ast-return-from
                #:make-ast-set-slot-value
                #:make-ast-setq
                #:make-ast-tagbody
                #:make-ast-throw
                #:make-ast-unwind-protect
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/arrays
                #:%php-array-ref-call-p
                #:%php-array-unset-call
  )
  (:import-from #:cl-cc/php/errors
                #:php-exception
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-call
                #:%php-exception-payload-call
                #:%php-lower-reference-assignments
                #:%php-rewrite-ref-vars
                #:%php-truthy-call
                #:%php-void-cast-ast
                #:%php-void-cast-start-p
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/generators
                #:%php-foreach-pairs
                #:%php-foreach-values
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-consume-expected
                #:%php-cst-interior
                #:%php-keyword-p
                #:%php-reference-token-p
                #:%PARSER-PHP-RUNTIME-SYMBOL
                #:%php-tok-to-cst
                #:%php-unsupported
                #:*php-current-imports*
                #:*php-current-namespace*
                #:*php-keyword-statement-parsers*
                #:*php-pending-top-level-forms*
                #:*php-statement-attribute-attacher*
                #:*php-statement-attribute-parser*
                #:*php-stmt-parsers*
                #:define-php-stmt-parser
                #:php-annotate-top-level-node
                #:php-at-eof-p
                #:php-consume
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
                #:register-php-cst-keyword-statement-parser
                #:register-php-cst-statement-parser
                #:register-php-source-finalizer
                #:register-php-source-statement-parser
  )
  (:import-from #:cl-cc/php/types
                #:+php-null+
  )
  (:export
   #:php-cst-parse-block
   #:php-cst-parse-statement
   #:php-parse-block
   #:php-parse-statement
  )
)
(in-package #:cl-cc/php/statements)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

