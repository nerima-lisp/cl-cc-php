;;;; parser-call-args.lisp — PHP argument-list syntax beyond plain positional
;;;; arguments.
;;;;
;;;; Named arguments (PHP 8.0, `f(name: $v)`) and first-class callables
;;;; (PHP 8.1, `strlen(...)`) are one concern: both are decided by looking at
;;;; the token immediately after the opening paren of a call, and both end up
;;;; rewriting the argument list the ordinary call parser would have built.
;;;;
;;;; Called from parser-expr-operator.lisp, which is compiled before this file;
;;;; that forward reference predates the split.

(in-package :cl-cc/php)

;;; ─── Named Arguments (PHP 8.0) ──────────────────────────────────────────────
;;;
;;; Named arguments allow passing arguments by parameter name:
;;;
;;;   htmlspecialchars(string: $str, flags: ENT_QUOTES, double_encode: false)
;;;
;;; The parser detects IDENT : patterns and tags them as :named in the arg list.

(defun %php-named-arg-p (stream)
  "Return true when STREAM starts with IDENT : (named argument syntax).
Distinguishes from ternary ? : because the token type is :T-COLON not :T-NULLABLE."
  (and stream
       (member (php-peek-type stream) '(:T-IDENT :T-TYPE) :test #'eq)
       (cdr stream)
       (eq (php-peek-type (cdr stream)) :T-COLON)))

(defun %php-arg-descriptor-expression (descriptor)
  "Return the AST expression carried by a parsed PHP call argument DESCRIPTOR."
  (ecase (first descriptor)
    (:positional (second descriptor))
    (:named (third descriptor))
    (:spread (second descriptor))))

(defun %php-named-args-to-positional (arg-descriptors)
  "Lower named args to positional ast expressions for the call AST.
Named args appear as :positional after reordering since the call AST only
holds a flat list. Unknown name order is preserved in declaration order."
  (mapcar #'%php-arg-descriptor-expression arg-descriptors))

;;; ─── First-Class Callables (PHP 8.1) ────────────────────────────────────────
;;;
;;; PHP 8.1 allows creating callable references with `...`:
;;;
;;;   $fn = strlen(...);
;;;   $closure = $obj->method(...);
;;;
;;; We detect T-ELLIPSIS as the sole argument in a call arglist and lower to
;;; a runtime callable reference.

(defun %php-first-class-callable-p (stream)
  "Return true when STREAM holds `( ... )` — first-class callable syntax."
  (and stream
       (eq (php-peek-type stream) :T-LPAREN)
       (cdr stream)
       (eq (php-peek-type (cdr stream)) :T-ELLIPSIS)
       (cddr stream)
       (eq (php-peek-type (cddr stream)) :T-RPAREN)))

(defun %php-callable-ref (func-name-ast)
  "Create a callable reference AST. Returns a lambda that calls FUNC-NAME-AST."
  ;; Lower strlen(...) to a callable trampoline that applies the PHP function.
  (let ((args-sym (gensym "CALLABLE-ARGS-")))
    (make-ast-lambda
     :params (list args-sym)
     :body (list (make-ast-call
                  :func (make-ast-var :name 'apply)
                  :args (list func-name-ast (make-ast-var :name args-sym)))))))

