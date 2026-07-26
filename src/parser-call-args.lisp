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

(defun %php-named-arg-pair-ast (pair)
  "Return an AST list representing one runtime named-argument PAIR."
  (make-ast-list
   :elements (list (make-ast-quote :value (car pair))
                   (cdr pair))))

(defun %php-parse-named-args (stream known-vars)
  "Parse mixed positional and named args up to T-RPAREN (exclusive).
Returns (values arg-list rest known-vars) where each arg is
(:positional expr) or (:named name expr).
The opening T-LPAREN must already have been consumed by the caller."
  (if (eq (php-peek-type stream) :T-RPAREN)
      (values nil stream known-vars)
      (let ((args nil)
            (current stream)
            (kv known-vars))
        (loop
          (cond
            ;; Spread operator: ...$args
            ((and (eq (php-peek-type current) :T-ELLIPSIS))
             (multiple-value-bind (_tok rest) (php-consume current)
               (declare (ignore _tok))
               (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest kv)
                 (push (list :spread expr) args)
                 (setf current rest2 kv kv2))))
            ;; Named argument: ident : expr
            ((%php-named-arg-p current)
             (let ((arg-name (php-tok-value (php-peek current))))
               (setf current (cddr current))        ; skip ident and colon
               (multiple-value-bind (expr rest2 kv2) (php-parse-expr current kv)
                 (push (list :named arg-name expr) args)
                 (setf current rest2 kv kv2))))
            ;; Positional argument
            (t
             (multiple-value-bind (expr rest2 kv2) (php-parse-expr current kv)
               (push (list :positional expr) args)
               (setf current rest2 kv kv2))))
          (if (and current (eq (php-peek-type current) :T-COMMA))
              (setf current (cdr current))
              (return)))
        (values (nreverse args) current kv))))

(defun %php-named-args-to-positional (arg-descriptors)
  "Lower named args to positional ast expressions for the call AST.
Named args appear as :positional after reordering since the call AST only
holds a flat list. Unknown name order is preserved in declaration order."
  (mapcar #'%php-arg-descriptor-expression arg-descriptors))

(defun %php-apply-named-args (func positional named-alist)
  "Build a PHP function call AST applying NAMED-ALIST overrides after POSITIONAL args.
Named args are appended as a list of (name . value) pairs in a runtime helper
call so the callee can do keyword-style dispatch."
  ;; For now we lower named args to a flat positional call with named args spliced
  ;; in the order they appear. A future pass could reorder by parameter name.
  (let* ((named-ast-pairs
           (mapcar #'%php-named-arg-pair-ast named-alist))
         (all-args (append positional named-ast-pairs)))
    (make-ast-call :func func :args all-args)))

(defun %php-parse-arglist-named (stream known-vars)
  "Parse (arg1, name: val, ...) supporting named arguments.
Assumes stream starts with T-LPAREN.
Returns (values arg-list rest known-vars) where each element is a plain AST
expression (named args are interleaved as positional for now)."
  (multiple-value-bind (tok rest) (php-expect :T-LPAREN stream)
    (declare (ignore tok))
    (multiple-value-bind (arg-descs rest2 kv2)
        (%php-parse-named-args rest known-vars)
      (multiple-value-bind (tok2 rest3) (php-expect :T-RPAREN rest2)
        (declare (ignore tok2))
        (values (%php-named-args-to-positional arg-descs) rest3 kv2)))))

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

(defun %php-parse-first-class-callable (func-ast stream known-vars)
  "Parse `(...)` after FUNC-AST and lower to a callable reference.
STREAM must begin with T-LPAREN. Returns (values callable-ref rest known-vars)."
  ;; consume ( ... )
  (let* ((rest1 (cdr stream))          ; skip (
         (rest2 (cdr rest1))           ; skip ...
         (rest3 (cdr rest2)))          ; skip )
    (values (%php-callable-ref func-ast) rest3 known-vars)))
