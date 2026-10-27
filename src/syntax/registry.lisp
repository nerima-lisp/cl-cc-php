;;;; syntax/registry.lisp — feature extension points for PHP grammar parsing

(in-package #:cl-cc/php/syntax)

(defvar *php-stmt-parsers* (make-hash-table)
  "Maps PHP keyword values to AST statement parser functions.")

(defmacro define-php-stmt-parser (keyword (stream known-vars) &body body)
  "Register a statement parser for KEYWORD in *php-stmt-parsers*."
  `(setf (gethash ,keyword *php-stmt-parsers*)
         (lambda (,stream ,known-vars) ,@body)))

(defvar *php-cst-keyword-expression-parsers* (make-hash-table)
  "Maps PHP expression keywords to feature-owned CST parser functions.")

(defun register-php-cst-keyword-expression-parser (keyword parser)
  (setf (gethash keyword *php-cst-keyword-expression-parsers*) parser))

(defvar *php-cst-primary-parsers* (make-hash-table)
  "Maps PHP primary token types to feature-owned CST parser functions.")

(defun register-php-cst-primary-parser (token-type parser)
  (setf (gethash token-type *php-cst-primary-parsers*) parser))

(defvar *php-keyword-statement-parsers* (make-hash-table)
  "Maps PHP statement keywords to feature-owned CST parser functions.")

(defun register-php-cst-keyword-statement-parser (keyword parser)
  (setf (gethash keyword *php-keyword-statement-parsers*) parser))

(defvar *php-statement-attribute-parser* nil
  "Optional feature callback that parses leading attributes for a statement.")

(defun register-php-statement-attribute-parser (parser)
  (setf *php-statement-attribute-parser* parser))

(defvar *php-statement-attribute-attacher* nil
  "Optional feature callback that attaches attributes to a parsed statement.")

(defun register-php-statement-attribute-attacher (attacher)
  (setf *php-statement-attribute-attacher* attacher))

(defvar *php-source-statement-parser* nil
  "Feature callback used by PARSE-PHP-SOURCE to parse statements.")

(defun register-php-source-statement-parser (parser)
  (setf *php-source-statement-parser* parser))

(defvar *php-source-state-initializer* nil
  "Feature callback returning symbol/value bindings for a source parse.")

(defun register-php-source-state-initializer (initializer)
  (setf *php-source-state-initializer* initializer))

(defvar *php-source-finalizers* (make-hash-table)
  "Ordered source-level AST finalizer callbacks keyed by integer phase.")

(defun register-php-source-finalizer (phase finalizer)
  (setf (gethash phase *php-source-finalizers*) finalizer))
(progn
  (defvar *php-expression-keyword-parsers* (make-hash-table)
    "Maps PHP expression keywords to feature parser functions.")

  (defun register-php-expression-keyword-parser (keyword parser)
    (setf (gethash keyword *php-expression-keyword-parsers*) parser))

  (defvar *php-expression-primary-parsers* (make-hash-table)
    "Maps PHP primary token types to feature parser functions.")

  (defun register-php-expression-primary-parser (token-type parser)
    (setf (gethash token-type *php-expression-primary-parsers*) parser))

  (defvar *php-expression-function-call-parser* nil
    "Feature callback that parses named PHP function calls.")

  (defun register-php-expression-function-call-parser (parser)
    (setf *php-expression-function-call-parser* parser))

  (defvar *php-array-expression-lowerers* (make-hash-table)
    "Maps array expression lowering operations to feature functions.")

  (defun register-php-array-expression-lowerer (operation function)
    (setf (gethash operation *php-array-expression-lowerers*) function))

  (defun call-php-array-expression-lowerer (operation &rest args)
    (apply (gethash operation *php-array-expression-lowerers*) args))

  (defvar *php-expression-method-call-lowerer* nil
    "Feature callback that lowers a PHP method call.")

  (defun register-php-expression-method-call-lowerer (lowerer)
    (setf *php-expression-method-call-lowerer* lowerer))

  (defvar *php-expression-dynamic-call-lowerer* nil
    "Feature callback that lowers a PHP dynamic call.")

  (defun register-php-expression-dynamic-call-lowerer (lowerer)
    (setf *php-expression-dynamic-call-lowerer* lowerer))

  (defvar *php-expression-constant-resolver* nil
    "Feature callback that resolves PHP predefined constants.")

  (defvar *php-expression-dynamic-constant-resolver* nil
    "Feature callback that resolves dynamic PHP predefined constants.")

  (defun register-php-expression-constant-resolvers
      (constant-resolver dynamic-resolver)
    (setf *php-expression-constant-resolver* constant-resolver
          *php-expression-dynamic-constant-resolver* dynamic-resolver))
  (progn
  (defvar *php-expression-static-member-lowerers* nil
    "Feature callbacks for PHP static method and member expressions.")

  (defun register-php-expression-static-member-lowerer (lowerer)
    (check-type lowerer function)
    (push lowerer *php-expression-static-member-lowerers*)
    lowerer)

  (defun call-php-expression-static-member-lowerers (object member args method-p)
    (dolist (lowerer *php-expression-static-member-lowerers* (values nil nil))
      (multiple-value-bind (value handled-p)
          (funcall lowerer object member args method-p)
        (when handled-p
          (return (values value t))))))

  (defvar *php-expression-callable-resolver* nil
    "Feature callback for resolving PHP callable values.")

  (defun register-php-expression-callable-resolver (resolver)
    (check-type resolver function)
    (when *php-expression-callable-resolver*
      (error "PHP expression callable resolver is already registered."))
    (setf *php-expression-callable-resolver* resolver))

  (defun call-php-expression-callable-resolver (callable)
    (unless *php-expression-callable-resolver*
      (error "PHP expression callable resolver is not registered."))
    (funcall *php-expression-callable-resolver* callable))))

(in-package #:cl-cc/php/syntax)

(defvar *php-runtime-symbols* (make-hash-table :test 'eq))

(defun %php-runtime-symbol (key)
  (check-type key keyword)
  (multiple-value-bind (symbol present-p)
      (gethash key *php-runtime-symbols*)
    (if present-p
        symbol
        (error "No PHP runtime symbol is registered for ~S." key))))

(defun register-php-runtime-symbol (key symbol)
  (check-type key keyword)
  (check-type symbol symbol)
  (multiple-value-bind (registered present-p)
      (gethash key *php-runtime-symbols*)
    (when present-p
      (error "PHP runtime symbol key ~S is already registered as ~S."
             key registered))
    (setf (gethash key *php-runtime-symbols*) symbol)))
(progn
  (defvar *php-runtime-packages* nil
    "Packages whose PHP runtime helper functions are exposed to the bridge.")

  (defun register-php-runtime-package (package)
    (check-type package package)
    (when (member package *php-runtime-packages* :test (function eq))
      (error "PHP runtime package ~S is already registered." package))
    (setf *php-runtime-packages*
          (nconc *php-runtime-packages* (list package)))
    package)

  (defun php-runtime-packages ()
    (copy-list *php-runtime-packages*))

  (defvar *php-cst-statement-parser* nil
    "Feature callback that parses one PHP CST statement from a token stream.")

  (defun register-php-cst-statement-parser (parser)
    (check-type parser function)
    (when *php-cst-statement-parser*
      (error "PHP CST statement parser is already registered."))
    (setf *php-cst-statement-parser* parser))

  (register-php-runtime-package *package*))
