;;;; packages/php/src/parser-stmt-params.lisp — PHP Parser: type annotation and parameter-list parsing

(in-package :cl-cc/php)

(defun %php-type-keyword-token-p (stream)
  "Return true when STREAM starts with a keyword valid in PHP type position."
  (and stream
       (eq (php-peek-type stream) :T-KEYWORD)
       (member (php-peek-value stream) '(:array :null :true :false) :test #'eq)))

(defun %php-type-atom-token-p (stream)
  "Return true when STREAM starts with a PHP type atom."
  (and stream
       (or (eq (php-peek-type stream) :T-TYPE)
           (eq (php-peek-type stream) :T-IDENT)
           (%php-type-keyword-token-p stream))))

(defun %php-type-token-string (token)
  "Return TOKEN's PHP spelling for metadata storage."
  (let ((value (php-tok-value token)))
    (string-downcase
     (etypecase value
       (keyword (symbol-name value))
       (symbol (symbol-name value))
       (string value)))))

(defun %php-parse-parenthesized-type (stream)
  "Parse a parenthesized PHP type group, used by PHP 8.2 DNF types."
  (let ((current (cdr stream))
        (parts nil))
    (multiple-value-bind (first-part rest) (%php-parse-type-term current)
      (unless first-part
        (return-from %php-parse-parenthesized-type (values nil stream)))
      (push first-part parts)
      (setf current rest))
    (loop while (and current
                     (eq (php-peek-type current) :T-OP)
                     (member (php-peek-value current) '("|" "&") :test #'equal))
          for op = (php-peek-value current)
          do (multiple-value-bind (part rest) (%php-parse-type-term (cdr current))
               (unless part
                 (return-from %php-parse-parenthesized-type (values nil stream)))
               (push op parts)
               (push part parts)
               (setf current rest)))
    (unless (eq (php-peek-type current) :T-RPAREN)
      (return-from %php-parse-parenthesized-type (values nil stream)))
    (values (format nil "(~A)" (apply #'concatenate 'string (nreverse parts)))
            (cdr current))))

(defun %php-parse-type-term (stream)
  "Parse one PHP type atom or parenthesized type group."
  (cond
    ((%php-type-atom-token-p stream)
     (values (%php-type-token-string (php-peek stream)) (cdr stream)))
    ((eq (php-peek-type stream) :T-LPAREN)
     (%php-parse-parenthesized-type stream))
    (t
     (values nil stream))))

(defun php-parse-type-annotation (stream)
  "Parse a PHP type annotation from STREAM.
Returns (values type-string remaining-stream). Handles nullable, union,
intersection, and PHP 8.2 DNF type syntax as metadata only."
  (let ((current stream)
        (parts nil))
    (when (eq (php-peek-type current) :T-NULLABLE)
      (push "?" parts)
      (setf current (cdr current)))
    (multiple-value-bind (first-part rest) (%php-parse-type-term current)
      (unless first-part
        (return-from php-parse-type-annotation (values nil stream)))
      (push first-part parts)
      (setf current rest))
    (loop while (and current
                     (eq (php-peek-type current) :T-OP)
                     (member (php-peek-value current) '("|" "&") :test #'equal)
                     (multiple-value-bind (part _rest)
                         (%php-parse-type-term (cdr current))
                       (declare (ignore _rest))
                       part))
          for op = (php-peek-value current)
          do (multiple-value-bind (part rest) (%php-parse-type-term (cdr current))
               (push op parts)
               (push part parts)
               (setf current rest)))
    (values (apply #'concatenate 'string (nreverse parts)) current)))

(defun %php-skip-type-annotation (stream)
  "Consume an optional type annotation from STREAM."
  (nth-value 1 (php-parse-type-annotation stream)))

(defun %php-parse-single-param (stream)
  "Parse one PHP parameter entry: attribute* visibility? readonly? type? &? ..? $var [= default].
Returns (values param-sym rest param-type param-attr-plist by-ref-p variadic-p)."
  (multiple-value-bind (attributes rest-after-attributes) (%php-parse-attributes stream)
    ;; PHP 8.0 constructor property promotion: visibility/readonly modifiers may
    ;; precede the type, e.g. __construct(public int $x).
    (multiple-value-bind (promo-modifiers rest-after-mods)
        (%php-parse-visibility-modifiers rest-after-attributes)
      (multiple-value-bind (param-type rest-after-type)
          (php-parse-type-annotation rest-after-mods)
        ;; PHP by-reference marker: &$param
        (let* ((by-ref-p (%php-reference-token-p rest-after-type))
               (rest-after-amp (if by-ref-p (cdr rest-after-type) rest-after-type))
               ;; PHP variadic parameter: ...$args
               (variadic-p (and (eq (php-peek-type rest-after-amp) :T-ELLIPSIS)))
               (rest-after-ellipsis (if variadic-p (cdr rest-after-amp) rest-after-amp)))
          (multiple-value-bind (var-tok rest) (php-expect :T-VAR rest-after-ellipsis)
            (let* ((param (php-var-sym (php-tok-value var-tok)))
                   (attr-plist
                    (when (or attributes promo-modifiers by-ref-p)
                      (cons param
                            (append (when attributes
                                      (%php-attribute-metadata attributes :parameter))
                                    (when promo-modifiers
                                      (list :php-promote promo-modifiers))
                                    (when by-ref-p
                                      (list :php-by-ref t)))))))
              (values param rest param-type attr-plist by-ref-p variadic-p))))))))

(defun php-parse-param-list (stream)
  "Parse (attribute* type? &? ..? $param [= default], ...).
Return (values params rest param-types param-attributes by-ref-indices
               param-defaults), where PARAM-DEFAULTS is an alist (param . default-ast)
for each parameter that has a default value. Callers that bind only the first five
values are unaffected."
  (let ((current (%php-consume-expected :T-LPAREN stream))
        (params nil)
        (param-types nil)
        (param-attributes nil)
        (by-ref-indices nil)
        (param-defaults nil)
        (variadic-param nil)
        (idx 0))
    (if (eq (php-peek-type current) :T-RPAREN)
        (values nil (cdr current) nil nil nil nil nil)
        (progn
          (loop
            (multiple-value-bind (param rest param-type attr-plist by-ref-p variadic-p)
                (%php-parse-single-param current)
              ;; A variadic parameter (...$args) is the AST rest-param, not a
              ;; positional one, so it is kept separate from PARAMS.
              (if variadic-p
                  (setf variadic-param param)
                  (push param params))
              (when param-type
                (push (cons param param-type) param-types))
              (when attr-plist
                (push attr-plist param-attributes))
              (when by-ref-p
                (push idx by-ref-indices))
              (setf current rest)
              (incf idx))
            ;; Optional default value: parse the default expression and record it
            ;; against the just-parsed parameter (the most recent PARAMS entry).
            ;; PHP default expressions are constant, so they are parsed with no
            ;; known variables; php-parse-expr stops at the comma / close paren.
            (when (and current (eq (php-peek-type current) :T-OP)
                       (equal "=" (php-peek-value current)))
              (multiple-value-bind (default-ast rest2)
                  (php-parse-expr (cdr current) nil)
                (push (cons (first params) default-ast) param-defaults)
                (setf current rest2)))
            (if (eq (php-peek-type current) :T-COMMA)
                (setf current (cdr current))
                (return)))
          (values (nreverse params)
                  (%php-consume-expected :T-RPAREN current)
                  (nreverse param-types)
                  (nreverse param-attributes)
                  (nreverse by-ref-indices)
                  (nreverse param-defaults)
                  variadic-param)))))

(defun %php-variadic-rest-binding (variadic-param body-forms)
  "Given the variadic parameter symbol (or NIL) and the callable BODY-FORMS list,
return (values rest-param-sym wrapped-body). When variadic, the AST rest-param is
a fresh symbol that collects the trailing arguments as a Common Lisp list; the
body is wrapped in a let that binds VARIADIC-PARAM to that list converted to a PHP
ordered array (PHP variadics are arrays, not lists). When not variadic, returns
(values nil BODY-FORMS) unchanged."
  (if variadic-param
      (let ((raw (gensym "PHP-VARIADIC-")))
        (values raw
                (list (make-ast-let
                       :bindings (list (cons variadic-param
                                             (make-ast-call
                                              :func (make-ast-var :name 'cl-cc/php::%php-list-to-array)
                                              :args (list (make-ast-var :name raw)))))
                       :body body-forms))))
      (values nil body-forms)))

(defun %php-split-params-by-defaults (params param-defaults)
  "Split PARAMS into (values required-params optional-param-entries) for an AST
callable. PARAM-DEFAULTS is the (param . default-ast) alist from
php-parse-param-list. A parameter with a default — and (PHP semantics) every
parameter after it — becomes an optional-param entry (name default-ast nil);
parameters before the first defaulted one stay required. An optional parameter
with no explicit default defaults to PHP null."
  (if (null param-defaults)
      (values params nil)
      (let ((first-optional
              (loop for p in params
                    when (assoc p param-defaults :test #'eq) return p)))
        (let ((required nil) (optionals nil) (seen-optional nil))
          (dolist (p params)
            (when (eq p first-optional) (setf seen-optional t))
            (if seen-optional
                (push (list p
                            (or (cdr (assoc p param-defaults :test #'eq))
                                (%php-null-quote))
                            nil)
                      optionals)
                (push p required)))
          (values (nreverse required) (nreverse optionals))))))

(defun php-parse-return-type (stream)
  "Parse an optional : type annotation after a function parameter list."
  (if (and stream (eq (php-peek-type stream) :T-COLON))
      (php-parse-type-annotation (cdr stream))
      (values nil stream)))

(defun %php-function-type-declarations (param-types return-type &optional returns-by-ref)
  "Build PHP type metadata plist for AST callable declarations."
  (append (when param-types (list :php-param-types param-types))
          (when return-type (list :php-return-type return-type))
          (when returns-by-ref (list :php-returns-by-ref t))))

(defun %php-function-declarations (param-types return-type param-attributes attributes target-type
                                   &optional returns-by-ref)
  "Build PHP callable metadata including types and attributes."
  (append (%php-function-type-declarations param-types return-type returns-by-ref)
          (when param-attributes (list :php-param-attributes param-attributes))
          (%php-attribute-metadata attributes target-type)))
