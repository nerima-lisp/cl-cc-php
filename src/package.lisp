;;;; src/package.lisp — the one package cl-cc-php defines.

;;; :USE names only #:CL. The sibling compiler packages this frontend is built
;;; on — cl-cc/ast for the AST it emits, cl-cc/parse for the CST and grammar
;;; machinery, cl-cc/bootstrap for the VM callable bridge — are taken in
;;; symbol by symbol instead. :USE'ing them would make the origin of a name
;;; unreadable at the call site, and would break this build the moment one of
;;; them exports a name that collides with one of the ~700 %PHP-* symbols
;;; defined here. With :IMPORT-FROM a collision is limited to the names listed
;;; below, and the list itself records exactly which part of the compiler the
;;; PHP frontend leans on.

(defpackage #:cl-cc/php
  (:use #:cl)

  (:import-from #:cl-cc/ast
                ;; Node types, matched with TYPEP and specialised on with DEFMETHOD.
                #:ast-node
                #:ast-defun
                #:ast-error
                #:ast-lambda
                #:ast-var
                ;; Constructors.
                #:make-ast-apply
                #:make-ast-binop
                #:make-ast-block
                #:make-ast-call
                #:make-ast-catch
                #:make-ast-defclass
                #:make-ast-defun
                #:make-ast-defvar
                #:make-ast-go
                #:make-ast-handler-case
                #:make-ast-if
                #:make-ast-int
                #:make-ast-lambda
                #:make-ast-let
                #:make-ast-list
                #:make-ast-make-instance
                #:make-ast-multiple-value-bind
                #:make-ast-multiple-value-call
                #:make-ast-multiple-value-prog1
                #:make-ast-print
                #:make-ast-progn
                #:make-ast-quote
                #:make-ast-return-from
                #:make-ast-set-gethash
                #:make-ast-set-slot-value
                #:make-ast-setq
                #:make-ast-slot-def
                #:make-ast-slot-value
                #:make-ast-tagbody
                #:make-ast-the
                #:make-ast-throw
                #:make-ast-unwind-protect
                #:make-ast-values
                #:make-ast-var
                ;; Accessors and predicates.
                #:ast-apply-args
                #:ast-apply-func
                #:ast-apply-p
                #:ast-binop-lhs
                #:ast-binop-op
                #:ast-binop-p
                #:ast-binop-rhs
                #:ast-block-body
                #:ast-block-name
                #:ast-block-p
                #:ast-call-args
                #:ast-call-func
                #:ast-call-p
                #:ast-catch-body
                #:ast-catch-p
                #:ast-catch-tag
                #:ast-children
                #:ast-defclass-name
                #:ast-defclass-p
                #:ast-defclass-php-kind
                #:ast-defclass-slots
                #:ast-defclass-superclasses
                #:ast-defun-body
                #:ast-defun-declarations
                #:ast-defun-documentation
                #:ast-defun-key-params
                #:ast-defun-name
                #:ast-defun-optional-params
                #:ast-defun-p
                #:ast-defun-params
                #:ast-defun-rest-param
                #:ast-handler-case-clauses
                #:ast-handler-case-form
                #:ast-handler-case-p
                #:ast-if-cond
                #:ast-if-else
                #:ast-if-p
                #:ast-if-then
                #:ast-imports
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
                #:ast-make-instance-class
                #:ast-make-instance-initargs
                #:ast-make-instance-p
                #:ast-multiple-value-bind-p
                #:ast-multiple-value-call-p
                #:ast-multiple-value-prog1-p
                #:ast-mv-call-args
                #:ast-mv-call-func
                #:ast-mv-prog1-first
                #:ast-mv-prog1-forms
                #:ast-mvb-body
                #:ast-mvb-values-form
                #:ast-mvb-vars
                #:ast-namespace
                #:ast-node-p
                #:ast-print-expr
                #:ast-print-p
                #:ast-progn-forms
                #:ast-progn-p
                #:ast-quote-p
                #:ast-quote-value
                #:ast-return-from-name
                #:ast-return-from-p
                #:ast-return-from-value
                #:ast-set-gethash-key
                #:ast-set-gethash-p
                #:ast-set-gethash-table
                #:ast-set-gethash-value
                #:ast-set-slot-value-object
                #:ast-set-slot-value-p
                #:ast-set-slot-value-slot
                #:ast-set-slot-value-value
                #:ast-setq-p
                #:ast-setq-value
                #:ast-setq-var
                #:ast-slot-allocation
                #:ast-slot-def-p
                #:ast-slot-initform
                #:ast-slot-name
                #:ast-slot-value-object
                #:ast-slot-value-p
                #:ast-slot-value-slot
                #:ast-tagbody-p
                #:ast-tagbody-tags
                #:ast-the-p
                #:ast-the-type
                #:ast-the-value
                #:ast-throw-p
                #:ast-throw-tag
                #:ast-throw-value
                #:ast-unwind-cleanup
                #:ast-unwind-protect-p
                #:ast-unwind-protected
                #:ast-values-forms
                #:ast-values-p
                #:ast-var-name
                #:ast-var-p)

  (:import-from #:cl-cc/bootstrap
                ;; Backend self-registration, needed at load time by
                ;; runtime-bridge-provider.lisp.
                #:register-backend-parser
                #:register-backend-bridge-provider
                ;; Hooks the runtime installs itself into so that PHP callables
                ;; become callable from compiled VM code.
                #:*runtime-vm-callable-register-hook*
                #:*vm-runtime-callable-installer*
                #:make-cst-token)

  (:import-from #:cl-cc/parse
                #:def-grammar-rule
                #:make-cst-interior
                #:make-parse-error)
  (:export
   #:tokenize-php-source
   #:parse-php-source
   #:parse-php-source-to-cst
   #:php-attribute
   #:make-php-attribute
   #:php-attribute-name
   #:php-attribute-args
   #:php-attribute-target-type
   #:%php-parse-attributes
   #:%php-parse-attribute-group
   #:%php-parse-attribute
   #:%php-skip-attributes
   #:+php-null+
   #:%php-array
   #:%php-array-empty-p
   #:%php-array-ref
   #:%php-array-set
   #:%php-array-unset
   #:%php-eq-loose
   #:%php-eq-strict
   #:%php-null-p
   #:%php-to-number
   #:%php-truthy
   #:%php-value-type
   #:%php-count
   #:%php-strlen
   #:%php-strtolower
   #:%php-strtoupper
   #:%php-stringify
   #:%php-concat
   #:%php-modulo
   #:%php-shift-left
   #:%php-shift-right
   #:%php-spaceship
   #:%php-bitwise-and
   #:%php-bitwise-or
   #:%php-bitwise-xor
   #:%php-bitwise-not
   #:%php-isset
   #:%php-compact
   #:%php-extract
   #:%php-clone
   #:%php-clone-with
   #:%php-array-key-exists
   #:%php-yield
   #:%php-yield-from
   #:%php-throw
   #:%php-make-exception
   #:%php-exception-object-p
   #:%php-exception-value
   #:%php-exception-matches-p
   #:%php-enum-make-case
   #:%php-enum-cases
   #:%php-enum-case-list
   #:%php-enum-from
   #:%php-enum-try-from
   #:%php-enum-case-value
   #:php-exception
   #:php-check-supported-forms
   #:*php-trait-registry*
   #:%php-parse-trait-decl
   #:%php-parse-use-trait-stmt
   #:*php-interface-registry*
   #:%php-parse-interface-decl
   #:%php-fiber-make
   #:%php-fiber-start
   #:%php-fiber-resume
   #:%php-fiber-suspend
   #:%php-array-first
   #:%php-array-last
   #:%php-array-find
   #:%php-array-find-key
   #:%php-array-any
   #:%php-array-all
   #:%php-callable-ref
   #:%php-pipe
   #:%php-get-error-handler
   #:%php-get-exception-handler
   #:%php-current-closure
   #:%php-grapheme-levenshtein
   #:%php-locale-is-right-to-left
   #:%php-locale-add-likely-subtags
   #:%php-locale-minimize-subtags
   #:%php-predefined-class-constant
   #:%php-opcache-is-script-cached-in-file-cache
   #:%php-curl-share-init-persistent
   #:%php-curl-multi-get-handles
   #:%php-enchant-dict-remove-from-session
   #:%php-enchant-dict-remove
   #:%php-pg-close-stmt
   #:%php-pg-service
   #:%php-filter-var
   ;; Reference / by-ref semantics
   #:php-ref-p
   #:%php-ref-p
   #:%php-make-ref
   #:%php-deref
   #:%php-ref-set!
   #:*php-by-ref-param-registry*
   #:*php-named-param-registry*
   ;; foreach by-reference
   #:%php-foreach-by-ref
   ;; Generator (yield/yield-from/send
   #:php-generator-p
   #:%php-generator-p
   #:%php-make-generator
   #:%php-generator-next
   #:%php-generator-send
   #:%php-generator-valid
   #:%php-generator-current
   #:%php-generator-get-return
   #:*current-generator*))
