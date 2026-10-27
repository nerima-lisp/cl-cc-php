;;;; parser-stmt-lowering.lisp — PHP Parser: Statement infrastructure and AST lowering

(in-package #:cl-cc/php/statements)

;;; %php-consume-expected and %php-keyword-p are defined in parser.lisp

(defun %php-include-keyword-value (value)
  "Normalize include/require identifiers or keywords to statement keywords."
  (let ((name (string-downcase (if (symbolp value) (symbol-name value) (princ-to-string value)))))
    (cond ((string= name "include") :include)
          ((string= name "require") :require)
          ((member name '("include_once" "include-once") :test #'string=) :include-once)
          ((member name '("require_once" "require-once") :test #'string=) :require-once)
          ((string= name "declare") :declare)
          ((string= name "goto") :goto)
          ((string= name "namespace") :namespace)
          ((string= name "use") :use)
          (t nil))))

(defun %php-parse-paren-expr (stream known-vars)
  "Parse a parenthesized expression."
  (let ((rest (%php-consume-expected :T-LPAREN stream)))
    (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
      (values expr (%php-consume-expected :T-RPAREN rest2) kv2))))

(defun %php-parse-expr-stmt (stream known-vars)
  "Parse an expression statement."
  (if (%php-void-cast-start-p stream)
      (let ((rest (cdddr stream)))
        (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
          (values (%php-void-cast-ast expr) (php-skip-semis rest2) kv2)))
      (multiple-value-bind (expr rest kv) (php-parse-expr stream known-vars)
        (values expr (php-skip-semis rest) kv))))

(defvar *php-loop-continue-target* nil
  "Dynamically bound innermost loop continue target.")

(defvar *php-loop-break-target* nil
  "Dynamically bound innermost loop/switch break target.")

(defvar *php-break-targets* nil
  "Dynamically bound stack of loop/switch break targets, innermost first.")

(defvar *php-continue-targets* nil
  "Dynamically bound stack of loop continue targets, innermost first.")

(defun %php-break-target (level)
  "Return the break target for LEVEL, where 1 means the innermost loop/switch."
  (let ((index (max 0 (1- (or level 1)))))
    (if level
        (nth index *php-break-targets*)
        (or (first *php-break-targets*)
            *php-loop-break-target*))))

(defun %php-continue-target (level)
  "Return the continue target for LEVEL, where 1 means the innermost loop."
  (let ((index (max 0 (1- (or level 1)))))
    (if level
        (nth index *php-continue-targets*)
        (or (first *php-continue-targets*)
            *php-loop-continue-target*))))

(defun %php-parse-control-level (stream)
  "Parse an optional integer break/continue LEVEL and return LEVEL and STREAM."
  (if (eq (php-peek-type stream) :T-INT)
      (values (php-peek-value stream) (cdr stream))
      (values nil stream)))

(defun %php-skip-to-stmt-end (stream)
  "Skip tokens until a top-level semicolon or block close."
  (let ((current stream) (paren-depth 0) (brace-depth 0) (bracket-depth 0))
    (loop while current
          for type = (php-peek-type current)
          do (cond
               ((and (eq type :T-SEMI)
                     (zerop paren-depth) (zerop brace-depth) (zerop bracket-depth))
                (return (php-skip-semis current)))
               ((and (eq type :T-RBRACE)
                     (zerop paren-depth) (zerop brace-depth) (zerop bracket-depth))
                (return current))
               ((eq type :T-LPAREN) (incf paren-depth) (setf current (cdr current)))
               ((eq type :T-RPAREN) (decf paren-depth) (setf current (cdr current)))
               ((eq type :T-LBRACE) (incf brace-depth) (setf current (cdr current)))
               ((eq type :T-RBRACE) (decf brace-depth) (setf current (cdr current)))
               ((eq type :T-LBRACKET) (incf bracket-depth) (setf current (cdr current)))
               ((eq type :T-RBRACKET) (decf bracket-depth) (setf current (cdr current)))
               (t (setf current (cdr current)))))
    current))

(defun %php-make-tagbody (items &optional initial-tag)
  "Build an AST-TAGBODY from flat tag/form ITEMS.
Symbols and integers start new tag sections; AST nodes are accumulated under
the current tag, matching the core CL lowerer's ast-tagbody representation."
  (let ((tags nil)
        (current-tag initial-tag)
        (current-forms nil))
    (labels ((flush-current ()
               (when current-tag
                 (push (cons current-tag (nreverse current-forms)) tags))))
      (dolist (item items)
        (if (or (symbolp item) (integerp item))
            (progn
              (flush-current)
              (setf current-tag item
                    current-forms nil))
            (progn
              (unless current-tag
                (setf current-tag (gensym "TAGBODY-START-")))
              (push item current-forms))))
      (flush-current)
      (make-ast-tagbody :tags (nreverse tags)))))

(defun php-parse-block (stream known-vars)
  "Parse { stmt* }."
  (let ((current (%php-consume-expected :T-LBRACE stream))
        (stmts nil)
        (kv known-vars))
    (loop
      (setf current (php-skip-semis current))
      (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
        (return))
      (multiple-value-bind (stmt rest2 kv2) (php-parse-statement current kv)
        (when stmt (push stmt stmts))
        (setf current rest2 kv kv2)))
    ;; Nest empty-bodied variable lets over the rest of the block so locals are
    ;; visible to later statements (function bodies, loop/if blocks all flow here).
    (values (php-finish-let-bindings
             (%php-lower-reference-assignments (nreverse stmts) known-vars))
            (%php-consume-expected :T-RBRACE current) kv)))

(defun %php-parse-namespace-block-body (stream known-vars namespace-name)
  "Parse a braced namespace body and annotate each enclosed top-level form."
  (let ((*php-current-namespace* namespace-name)
        (*php-current-imports* nil)
        (*php-pending-top-level-forms* nil)
        (current (%php-consume-expected :T-LBRACE stream))
        (stmts nil)
        (kv known-vars))
    (loop
      (setf current (php-skip-semis current))
      (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
        (return))
      (multiple-value-bind (stmt rest2 kv2) (php-parse-statement current kv)
        (cond
          (*php-pending-top-level-forms*
           (dolist (form (reverse *php-pending-top-level-forms*))
             (push form stmts))
           (setf *php-pending-top-level-forms* nil))
          (stmt
           (push (php-annotate-top-level-node stmt) stmts)))
        (setf current rest2 kv kv2)))
    (values (php-finish-let-bindings
             (%php-lower-reference-assignments (nreverse stmts) known-vars))
            (%php-consume-expected :T-RBRACE current) kv)))

(defun %php-parse-statement-body (stream known-vars)
  "Parse either a braced block or one PHP statement. Return a statement list."
  (if (eq (php-peek-type stream) :T-LBRACE)
      (php-parse-block stream known-vars)
      (multiple-value-bind (stmt rest kv) (php-parse-statement stream known-vars)
        (values (%php-lower-reference-assignments
                 (if stmt (list stmt) nil)
                 known-vars)
                rest kv))))

(in-package #:cl-cc/php/statements)

;;; ─── Statement Dispatcher ────────────────────────────────────────────────────

(defun php-parse-statement (stream known-vars)
  "Parse a single PHP statement. Returns (values ast rest known-vars).
Dispatches keyword statements through *php-stmt-parsers*; falls through
to %php-parse-expr-stmt for expression statements."
  (multiple-value-bind (attributes stream)
      (if *php-statement-attribute-parser*
          (funcall *php-statement-attribute-parser* stream)
          (values nil stream))
    (labels ((attach-attributes (node &optional target-type)
               (if *php-statement-attribute-attacher*
                   (funcall *php-statement-attribute-attacher*
                            node attributes target-type)
                   node)))
      (cond
        ((eq (php-peek-type stream) :T-INLINE-HTML)
         (multiple-value-bind (tok rest) (php-consume stream)
           (values (attach-attributes
                    (%php-call (%PARSER-PHP-RUNTIME-SYMBOL :output-write)
                               (make-ast-quote :value (php-tok-value tok))))
                   rest known-vars)))
        ((and (eq (php-peek-type stream) :T-IDENT)
              (let ((next (second stream)))
                (and next (eq (php-tok-type next) :T-COLON))))
         (%php-unsupported
          (format nil "labeled statement `~A:` (goto~Cs jump target) is not yet supported"
                  (php-peek-value stream) (code-char 39))))
        (t
         (let ((handler (when (eq (php-peek-type stream) :T-KEYWORD)
                          (gethash (php-peek-value stream) *php-stmt-parsers*))))
           (if handler
               (multiple-value-bind (_ rest) (php-consume stream)
                 (multiple-value-bind (stmt rest2 kv2)
                     (funcall handler rest known-vars)
                   (let ((target-type (case (php-tok-value _)
                                        ((:class :readonly) :class)
                                        (:const :constant)
                                        (:function :function)
                                        ((:trait :interface :enum) :class)
                                        (otherwise nil))))
                     (when (and attributes
                                (eq (php-tok-value _) :const)
                                (ast-progn-p stmt))
                       (error
                        (concatenate (quote string)
                                     "PHP parse error: attributes on grouped const "
                                     "declarations require exactly one constant")))
                     (values (attach-attributes stmt target-type)
                             rest2 kv2))))
               (multiple-value-bind (stmt rest2 kv2)
                   (%php-parse-expr-stmt stream known-vars)
                 (values (attach-attributes stmt) rest2 kv2)))))))))

(in-package #:cl-cc/php/statements)

;;; ─── Top-Level Entry Point ───────────────────────────────────────────────────

(defun php-finish-let-bindings (stmts)
  "Wrap each `ast-let' with an empty body around the statements that follow it.

PHP's first assignment to a variable lowers to (ast-let ((var . value)) :body nil)
— a declaration whose scope must cover every later statement in the same block.
Walking STMTS backwards, each empty-bodied let absorbs the already-nested tail as
its body, so `$x = 10; echo $x;' becomes (let (($x 10)) (echo $x)) rather than two
siblings where echo sees an unbound $x. Statements that are not empty-bodied lets
(including lets that already carry a body) pass through as siblings.

This pass is applied at top level and in every braced block (see
php-parse-block), keeping each first assignment visible to the later statements
that share the same PHP block scope."
  (let ((tail nil))
    (dolist (stmt (reverse stmts) tail)
      (if (and (ast-let-p stmt) (null (ast-let-body stmt)))
          (progn
            (setf (ast-let-body stmt) tail)
            (setf tail (list stmt)))
          (push stmt tail)))))
;;; ─── Top-Level Entry Point ───────────────────────────────────────────────────

(eval-when (:load-toplevel :execute)
  (register-php-source-statement-parser (function php-parse-statement))
  (register-php-source-finalizer 50 (function php-finish-let-bindings)))
