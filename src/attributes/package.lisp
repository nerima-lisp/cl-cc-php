(defpackage #:cl-cc/php/attributes
  (:use #:cl)
  (:import-from #:cl-cc/ast
                #:ast-block-body
                #:ast-block-p
                #:ast-call-func
                #:ast-call-p
                #:ast-catch-body
                #:ast-catch-p
                #:ast-defclass-name
                #:ast-defclass-p
                #:ast-defclass-slots
                #:ast-defun-body
                #:ast-defun-declarations
                #:ast-defun-name
                #:ast-defun-p
                #:ast-if-else
                #:ast-if-p
                #:ast-if-then
                #:ast-imports
                #:ast-let-bindings
                #:ast-let-body
                #:ast-let-p
                #:ast-make-instance-class
                #:ast-make-instance-p
                #:ast-multiple-value-bind-p
                #:ast-mvb-body
                #:ast-node-p
                #:ast-progn-forms
                #:ast-progn-p
                #:ast-quote-p
                #:ast-quote-value
                #:ast-setq-p
                #:ast-setq-value
                #:ast-setq-var
                #:ast-slot-def-p
                #:ast-slot-initform
                #:ast-slot-name
                #:ast-slot-value-object
                #:ast-slot-value-p
                #:ast-slot-value-slot
                #:ast-unwind-cleanup
                #:ast-unwind-protect-p
                #:ast-unwind-protected
                #:ast-var-name
                #:ast-var-p
                #:make-ast-int
                #:make-ast-progn
                #:make-ast-quote
  )
  (:import-from #:cl-cc/php/expressions
                #:%php-call
                #:%php-void-cast-progn-p
                #:php-parse-expr
  )
  (:import-from #:cl-cc/php/syntax
                #:%php-consume-expected
                #:%php-qualified-name-segment-string
                #:%php-runtime-symbol
                #:%php-strip-leading-namespace-separator
                #:php-ident-sym
                #:php-parse-qualified-name
                #:php-peek
                #:php-peek-type
                #:register-php-source-finalizer
                #:register-php-statement-attribute-attacher
                #:register-php-statement-attribute-parser
  )
  (:export
   #:%php-attach-attributes-to-node
   #:%php-attribute-metadata
   #:%php-attribute-short-name
   #:%php-metadata-get
   #:%php-parse-attribute
   #:%php-parse-attribute-group
   #:%php-parse-attributes
   #:make-php-attribute
   #:PHP-ATTRIBUTE
   #:php-attribute-args
   #:php-attribute-name
   #:php-attribute-p
   #:php-attribute-target-type)
)
(in-package #:cl-cc/php/attributes)
(eval-when (:load-toplevel :execute) (cl-cc/php/syntax:register-php-runtime-package *package*))

