(defpackage #:cl-cc/php/classes
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-children
                #:ast-defclass-name
                #:ast-defclass-p
                #:ast-defclass-php-kind
                #:ast-defclass-slots
                #:ast-defclass-superclasses
                #:ast-defun-body
                #:ast-defun-declarations
                #:ast-defun-name
                #:ast-defun-p
                #:ast-defun-params
                #:ast-error
                #:ast-imports
                #:ast-progn-forms
                #:ast-progn-p
                #:ast-slot-allocation
                #:ast-slot-def-p
                #:ast-slot-initform
                #:ast-slot-name
                #:ast-var-name
                #:ast-var-p
                #:make-ast-call
                #:make-ast-defclass
                #:make-ast-defun
                #:make-ast-if
                #:make-ast-let
                #:make-ast-make-instance
                #:make-ast-progn
                #:make-ast-quote
                #:make-ast-return-from
                #:make-ast-set-slot-value
                #:make-ast-slot-def
                #:make-ast-slot-value
                #:make-ast-var
  )
  (:import-from #:cl-cc/php/arrays
                #:%php-array-pairs
                #:%php-list-to-array
  )
  (:import-from #:cl-cc/php/attributes
                #:%php-attach-attributes-to-node
                #:%php-attribute-metadata
                #:%php-attribute-short-name
                #:%php-metadata-get
                #:%php-parse-attributes
                #:php-attribute-name
                #:php-attribute-p
  )
  (:import-from #:cl-cc/php/errors
                #:%php-throw
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-assignment-op-p
                #:%php-call
                #:%php-eq-strict
                #:*php-current-class*
                #:*php-current-supers*
                #:php-parse-arglist
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/functions
                #:%php-callable-body
                #:%php-member-slot-allocation
                #:php-parse-param-list
                #:php-parse-return-type
                #:register-php-parameter-modifier-parser
  )
  (:import-from #:cl-cc/php/statements
                #:php-cst-parse-statement
                #:php-parse-block
                #:php-parse-statement
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-consume-expected
                #:%php-cst-interior
                #:%PARSER-PHP-CST-PARSE-UNARY-KEYWORD-EXPRESSION
                #:%php-keyword-p
                #:%php-reference-token-p
                #:%PARSER-PHP-RUNTIME-SYMBOL
                #:%php-tok-to-cst
                #:%php-unsupported
                #:define-php-stmt-parser
                #:php-at-eof-p
                #:php-consume
                #:php-cst-parse-arglist
                #:php-expect
                #:php-ident-sym
                #:php-parse-qualified-name
                #:php-peek
                #:php-peek-type
                #:php-peek-value
                #:php-resolve-qualified-name
                #:php-skip-semis
                #:php-tok-value
                #:php-ts-advance
                #:php-ts-at-end-p
                #:php-ts-at-type-p
                #:php-ts-at-value-p
                #:php-ts-expect
                #:php-ts-peek-type
                #:php-ts-peek-value
                #:php-ts-skip-semis
                #:php-var-sym
                #:register-php-cst-keyword-expression-parser
                #:register-php-cst-keyword-statement-parser
                #:register-php-expression-keyword-parser
                #:register-php-expression-static-member-lowerer
                #:register-php-runtime-symbol
                #:register-php-source-finalizer
  )
  (:import-from #:cl-cc/php/types
                #:%php-null-p
                #:%php-stringify
                #:%php-type-atom-token-p
                #:+php-null+
                #:php-parse-type-annotation
  )
  (:export
   #:%php-clone
   #:%php-clone-with
   #:%php-enum-case-list
   #:%php-enum-case-value
   #:%php-enum-cases
   #:%php-enum-from
   #:%php-enum-make-case
   #:%php-enum-try-from
   #:%php-lower-property-with-hooks
   #:%php-mark-all-props-readonly
   #:%php-parse-asymmetric-visibility
   #:%php-parse-interface-decl
   #:%php-parse-use-trait-stmt
   #:*php-interface-registry*
   #:*php-trait-applications*
   #:*php-trait-registry*
   #:php-cst-parse-new
  )
)
(in-package #:cl-cc/php/classes)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

