;;;; parser-property-hooks.lisp — PHP 8.4 property hooks, asymmetric visibility,
;;;; and readonly properties.
;;;;
;;;; One concern: everything that changes how a *property declaration* in a
;;;; class body is parsed and lowered. Hooks synthesise __get_/__set_ methods,
;;;; `private(set)` splits read and write visibility, and `readonly` (property
;;;; or whole class, PHP 8.2) tags the slot. They share the slot-def metadata
;;;; path and are only ever reached from the class-body member parser.
;;;;
;;;; Load order: after parser-class.lisp, which supplies %php-slot-metadata and
;;;; calls %php-parse-property-slot-with-hooks below.

(in-package :cl-cc/php)

;;; ─── PHP 8.4 Property Hooks ─────────────────────────────────────────────────
;;;
;;; PHP 8.4 allows properties to have get/set hooks:
;;;
;;;   class User {
;;;     public string $name {
;;;       get { return $this->_name; }
;;;       set(string $v) { $this->_name = trim($v); }
;;;     }
;;;     public string $title {
;;;       get => $this->title;
;;;       set => $this->title = $value;
;;;     }
;;;     public private(set) string $id;
;;;   }
;;;
;;; Hooks lower to synthetic getter/setter methods prefixed __get_ / __set_.

(defun %php-parse-property-hook-short (stream known-vars)
  "Parse `=> expr` short hook body. Returns (values ast rest)."
  (multiple-value-bind (arrow-tok rest) (php-consume stream)
    (declare (ignore arrow-tok))
    (multiple-value-bind (expr rest2 _kv) (php-parse-expr rest known-vars)
      (declare (ignore _kv))
      (values expr rest2))))

(defun %php-parse-property-hook-long (stream known-vars)
  "Parse `{ stmts }` long hook body. Returns (values stmts rest)."
  (multiple-value-bind (body-stmts rest _kv) (php-parse-block stream known-vars)
    (declare (ignore _kv))
    (values body-stmts rest)))

(defun %php-parse-one-property-hook (stream known-vars)
  "Parse one hook clause: get or set(param). Returns (values kind param-sym ast rest)."
  (unless (and stream (eq (php-peek-type stream) :T-IDENT))
    (error "PHP 8.4 property hook error: expected 'get' or 'set', got ~S" (php-peek stream)))
  (multiple-value-bind (name-tok rest) (php-consume stream)
    (let* ((hook-kind (string-downcase (php-tok-value name-tok)))
           (param-sym nil)
           (current rest))
      (unless (member hook-kind '("get" "set") :test #'string=)
        (error "PHP 8.4 property hook error: unknown hook '~A', expected get or set" hook-kind))
      ;; set may have an optional typed parameter: set(Type $param)
      (when (and (string= hook-kind "set")
                 (eq (php-peek-type current) :T-LPAREN))
        (let ((inner (%php-consume-expected :T-LPAREN current)))
          (multiple-value-bind (_type after-type) (php-parse-type-annotation inner)
            (declare (ignore _type))
            (setf current after-type))
          (multiple-value-bind (var-tok after-var) (php-expect :T-VAR current)
            (setf param-sym (php-var-sym (php-tok-value var-tok))
                  current (%php-consume-expected :T-RPAREN after-var)))))
      ;; Body: => expr  OR  { stmts }
      (cond
        ((and (eq (php-peek-type current) :T-OP)
              (equal "=>" (php-peek-value current)))
         (multiple-value-bind (body-expr rest2)
             (%php-parse-property-hook-short current known-vars)
           (values (intern (string-upcase hook-kind) :keyword) param-sym body-expr rest2)))
        ((eq (php-peek-type current) :T-LBRACE)
         (multiple-value-bind (body-stmts rest2)
             (%php-parse-property-hook-long current known-vars)
           (values (intern (string-upcase hook-kind) :keyword) param-sym body-stmts rest2)))
        (t
         (error "PHP 8.4 property hook error: expected => or { after hook name, got ~S"
                (php-peek current)))))))

(defun %php-parse-property-hook-body (stream known-vars)
  "Parse { get {...} set(param) {...} } or { get => expr; set => expr; }.
Returns plist (:get getter-ast :set setter-ast :set-param set-param-sym) or nil."
  (unless (and stream (eq (php-peek-type stream) :T-LBRACE))
    (return-from %php-parse-property-hook-body (values nil stream)))
  (let ((current (%php-consume-expected :T-LBRACE stream))
        (getter-ast nil)
        (setter-ast nil)
        (setter-param nil))
    (loop
      (setf current (php-skip-semis current))
      (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
        (return))
      (multiple-value-bind (kind param-sym body rest2)
          (%php-parse-one-property-hook current known-vars)
        (case kind
          (:get (setf getter-ast body))
          (:set (setf setter-ast body setter-param param-sym))
          (t (error "PHP 8.4 property hook error: unexpected hook kind ~S" kind)))
        (setf current (php-skip-semis rest2))))
    (values (list :get getter-ast :set setter-ast :set-param setter-param)
            (%php-consume-expected :T-RBRACE current))))

(defun %php-lower-property-with-hooks (prop-name getter-ast setter-ast class-name
                                       &key (setter-param nil))
  "Generate getter __get_PropName and setter __set_PropName method ASTs.
Returns a list of ast-defun nodes."
  (declare (ignore class-name))
  (let* ((prop-str (symbol-name prop-name))
         (getter-name (php-ident-sym (format nil "__GET_~A" prop-str)))
         (setter-name (php-ident-sym (format nil "__SET_~A" prop-str)))
         (this-sym (php-var-sym "$this"))
         (value-sym (or setter-param (php-var-sym "$value")))
         (result nil))
    (when getter-ast
      (let ((body (if (listp getter-ast)
                      getter-ast
                      (list (make-ast-return-from :name nil :value getter-ast)))))
        (push (make-ast-defun :name getter-name
                              :params (list this-sym)
                              :declarations nil
                              :body (%php-callable-body body))
              result)))
    (when setter-ast
      (let ((body (if (listp setter-ast)
                      setter-ast
                      (list setter-ast))))
        (push (make-ast-defun :name setter-name
                              :params (list this-sym value-sym)
                              :declarations nil
                              :body (%php-callable-body body))
              result)))
    (nreverse result)))

(defun %php-parse-asymmetric-visibility (stream)
  "Parse public private(set) or public protected(set).
Returns (values outer-visibility inner-visibility rest-stream).
When no asymmetric visibility is found, inner-visibility is nil."
  (unless (and stream
               (eq (php-peek-type stream) :T-KEYWORD)
               (member (php-peek-value stream) '(:public :protected :private) :test #'eq))
    (return-from %php-parse-asymmetric-visibility
      (values nil nil stream)))
  (multiple-value-bind (outer-tok rest1) (php-consume stream)
    (let ((outer (php-tok-value outer-tok)))
      ;; Look for inner(set) pattern: keyword immediately followed by T-LPAREN
      (if (and rest1
               (eq (php-peek-type rest1) :T-KEYWORD)
               (member (php-peek-value rest1) '(:private :protected) :test #'eq)
               (cdr rest1)
               (eq (php-peek-type (cdr rest1)) :T-LPAREN))
          (multiple-value-bind (inner-tok rest2) (php-consume rest1)
            (let* ((inner (php-tok-value inner-tok))
                   (rest3 (%php-consume-expected :T-LPAREN rest2)))
              (unless (and rest3
                           (eq (php-peek-type rest3) :T-IDENT)
                           (string-equal (php-peek-value rest3) "set"))
                (error "PHP 8.4 asymmetric visibility: expected 'set' inside parentheses, got ~S"
                       (php-peek rest3)))
              (multiple-value-bind (_set-tok rest4) (php-consume rest3)
                (declare (ignore _set-tok))
                (values outer inner (%php-consume-expected :T-RPAREN rest4)))))
          ;; No inner visibility: just the outer keyword was consumed
          (values outer nil rest1)))))
;;; ─── Readonly classes (PHP 8.2) ─────────────────────────────────────────────
;;;
;;; `readonly class Foo {}` implicitly marks every promoted constructor
;;; property as readonly. Lowered by post-processing the parsed slot list.

(defun %php-mark-prop-readonly (member)
  "Return MEMBER with readonly metadata when it is an instance property slot."
  (if (and (ast-slot-def-p member)
           (eq (ast-slot-allocation member) :instance)
           (not (ast-defun-p (ast-slot-initform member))))
      (let ((copy (copy-structure member)))
        (setf (ast-imports copy)
              (append (ast-imports copy)
                      (list :readonly-p t)))
        copy)
      member))

(defun %php-mark-all-props-readonly (class-members)
  "Mark every property slot in CLASS-MEMBERS as readonly.
Only :instance allocation slots are affected; methods and constants are skipped."
  (mapcar #'%php-mark-prop-readonly class-members))
;;; ─── Readonly properties (PHP 8.1) ──────────────────────────────────────────
;;;
;;; A readonly property slot is identified by :readonly in the modifiers list;
;;; %php-parse-visibility-modifiers already collects it. This reads it back.

(defun %php-hook-method-slot (method-defun modifiers)
  "Wrap generated property hook METHOD-DEFUN in a method slot."
  (make-ast-slot-def
   :name (ast-defun-name method-defun)
   :initform method-defun
   :imports (%php-slot-metadata modifiers
                                :attributes nil
                                :target-type :method)))
;;; ─── Class-body integration ─────────────────────────────────────────────────
;;;
;;; %php-parse-property-slot-with-hooks is called from the class-body member
;;; parser when { appears after a property declaration. It returns both the
;;; original slot-def (for type/visibility metadata) and extra method slot-defs
;;; for the generated __get_* / __set_* accessors.

(defun %php-parse-property-slot-with-hooks (stream modifiers attributes class-name)
  "Parse a property that may be followed by { get/set hook(s) }.
Returns (values slot-def-list rest-stream).
When no hooks are present, the list contains only the original property slot."
  (multiple-value-bind (property-type after-type) (php-parse-type-annotation stream)
    (let ((current (if (and property-type (eq (php-peek-type after-type) :T-VAR))
                       after-type
                       stream))
          (slot-type (when (and property-type (eq (php-peek-type after-type) :T-VAR))
                       property-type)))
      (multiple-value-bind (var-tok rest) (php-consume current)
        (let* ((raw (php-tok-value var-tok))
               (bare (if (and (stringp raw) (plusp (length raw)) (char= (char raw 0) #\$))
                         (subseq raw 1)
                         raw))
               (prop-sym (php-ident-sym bare))
               (initform (make-ast-quote :value +php-null+))
               (base-slot (make-ast-slot-def
                           :name prop-sym
                           :type slot-type
                           :initform initform
                           :allocation (%php-member-slot-allocation modifiers)
                           :imports (%php-slot-metadata modifiers
                                                        :attributes attributes
                                                        :target-type :property))))
          ;; Check for optional default value
          (when (and rest (eq (php-peek-type rest) :T-OP)
                     (equal "=" (php-peek-value rest)))
            (multiple-value-bind (default-ast rest2) (php-parse-expr (cdr rest) nil)
              (setf (ast-slot-initform base-slot) default-ast
                    rest rest2)))
          ;; Check for property hooks { get ... set ... }
          (if (and rest (eq (php-peek-type rest) :T-LBRACE))
              (multiple-value-bind (hooks-plist rest2)
                  (%php-parse-property-hook-body rest nil)
                (if hooks-plist
                    (let* ((getter-ast (getf hooks-plist :get))
                           (setter-ast (getf hooks-plist :set))
                           (setter-param (getf hooks-plist :set-param))
                           (method-slots
                             (loop for method-defun in
                                   (%php-lower-property-with-hooks
                                    prop-sym getter-ast setter-ast class-name
                                    :setter-param setter-param)
                                   collect (%php-hook-method-slot method-defun modifiers))))
                      (values (cons base-slot method-slots)
                              (php-skip-semis rest2)))
                    (values (list base-slot) (php-skip-semis rest2))))
              (values (list base-slot) (php-skip-semis rest))))))))
