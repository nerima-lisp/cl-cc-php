;;;; parser-expr-new.lisp -- New-expression parsing and special runtime-backed class constructors.
;;;;
;;;; Split from parser-expr.lisp so expression domains stay independently reviewable.
(in-package #:cl-cc/php/classes)

(defun %php-parse-anonymous-class (stream known-vars)
  "Parse an anonymous class expression after `new class` (the `class` keyword is
already consumed): optional (ctor args), optional extends/implements, then a
class body. Returns (values ast rest kv) where ast is a progn that defines a
gensym-named class and makes an instance of it."
  (let ((current stream)
        (ctor-args nil)
        (kv known-vars)
        (anon-name (php-ident-sym (symbol-name (gensym "PHP-ANON-CLASS-")))))
    ;; Optional constructor argument list: new class (args) { ... }
    (when (eq (php-peek-type current) :T-LPAREN)
      (multiple-value-bind (args rest kv2) (php-parse-arglist current kv)
        (setf ctor-args args current rest kv kv2)))
    ;; Optional extends / implements
    (multiple-value-bind (supers rest) (%php-parse-class-superclasses current)
      (setf current rest)
      ;; Class body { members... }
      (let ((body (%php-consume-expected :T-LBRACE current))
            (slots nil))
        (loop
          (setf body (php-skip-semis body))
          (when (or (php-at-eof-p body) (eq (php-peek-type body) :T-RBRACE))
            (return))
          (multiple-value-bind (slot rest2) (%php-parse-class-body-member body known-vars)
            (when slot (push slot slots))
            (setf body rest2)))
        (setf current (%php-consume-expected :T-RBRACE body))
        (values
         (make-ast-progn
          :forms (list (make-ast-defclass :name anon-name
                                          :superclasses supers
                                          :slots (nreverse slots)
                                          :php-kind :class)
                       (make-ast-make-instance
                        :class (make-ast-var :name anon-name)
                        :initargs (loop for i from 0 for a in ctor-args
                                        collect (cons
                                                (intern (format nil "ARG~D" i) :keyword) a)))))
         current kv)))))

(defparameter *php-spl-builtin-classes*
  '("SPLSTACK" "SPLQUEUE" "SPLDOUBLYLINKEDLIST" "SPLMINHEAP" "SPLMAXHEAP"
    "SPLFIXEDARRAY"))

(defun %php-spl-builtin-class-p (class-name)
  (member (string-upcase (symbol-name class-name))
          *php-spl-builtin-classes*
          :test #'string=))

(defun %php-spl-new-ast (class-name args)
  (make-ast-call
   :func (make-ast-var :name (%php-runtime-symbol :spl-new))
   :args (cons (make-ast-quote :value (symbol-name class-name)) args)))

(defun %php-fiber-class-p (class-name)
  (string= (string-upcase (symbol-name class-name)) "FIBER"))

(defun %php-fiber-class-ast-p (obj)
  (and (ast-var-p obj)
       (%php-fiber-class-p (ast-var-name obj))))

(defun %php-closure-class-ast-p (obj)
  (and (ast-var-p obj)
       (string= (string-upcase (symbol-name (ast-var-name obj))) "CLOSURE")))

(defun %php-locale-class-ast-p (obj)
  (and (ast-var-p obj)
       (string= (string-upcase (symbol-name (ast-var-name obj))) "LOCALE")))

(defun %php-predefined-class-constant-class-ast-p (obj)
  (and (ast-var-p obj)
       (member (string-upcase (symbol-name (ast-var-name obj)))
               '("INTLLISTFORMATTER" "NUMBERFORMATTER" "PDO\\SQLITE"
                 "URI\\URICOMPARISONMODE")
               :test #'string=)))

(defun %php-fiber-new-ast (args)
  (make-ast-call
   :func (make-ast-var :name (%php-runtime-symbol :fiber-make))
   :args args))

(defun %php-uri-class-kind (class-name)
  (let ((name (string-upcase (symbol-name class-name))))
    (cond
      ((string= name "URI\\RFC3986\\URI") :rfc3986)
      ((string= name "URI\\WHATWG\\URL") :whatwg))))

(defun %php-uri-class-ast-kind (obj)
  (and (ast-var-p obj)
       (%php-uri-class-kind (ast-var-name obj))))

(defun %php-uri-new-ast (class-name args)
  (make-ast-call
   :func (make-ast-var :name (ecase (%php-uri-class-kind class-name)
                               (:rfc3986 (%php-runtime-symbol :uri-rfc3986-new))
                               (:whatwg (%php-runtime-symbol :uri-whatwg-new))))
   :args args))

(defun %php-uri-parse-ast (kind args)
  (make-ast-call
   :func (make-ast-var :name (ecase kind
                               (:rfc3986 (%php-runtime-symbol :uri-rfc3986-parse))
                               (:whatwg (%php-runtime-symbol :uri-whatwg-parse))))
   :args args))
(defun %php-class-static-member-lowerer (object member args method-p)
  (let ((member-name (string-upcase (symbol-name member))))
    (if (and method-p
             (member member-name '("CASES" "FROM" "TRYFROM") :test #'string=))
        (values
         (cond
           ((string= member-name "CASES")
            (%php-call (%php-runtime-symbol :enum-cases) object))
           ((string= member-name "FROM")
            (%php-call (%php-runtime-symbol :enum-from) object (first args)))
           (t
            (%php-call (%php-runtime-symbol :enum-try-from) object (first args))))
         t)
        (values nil nil))))

(defun %php-reflection-object-class-kind (class-name)
  (let ((name (string-upcase (symbol-name class-name))))
    (cond
      ((string= name "REFLECTIONCONSTANT") :constant)
      ((string= name "REFLECTIONPROPERTY") :property))))

(defun %php-reflection-new-ast (class-name args)
  (make-ast-call
   :func (make-ast-var :name (ecase (%php-reflection-object-class-kind class-name)
                               (:constant (%php-runtime-symbol :reflection-constant-new))
                               (:property (%php-runtime-symbol :reflection-property-new))))
   :args args))

(defun %php85-runtime-object-class-kind (class-name)
  (let ((name (string-upcase (symbol-name class-name))))
    (cond
      ((string= name "DOM\\ELEMENT") :dom-element)
      ((string= name "DOM\\HTMLDOCUMENT") :dom-html-document)
      ((string= name "PDO\\SQLITE") :pdo-sqlite)
      ((string= name "SOAPCLIENT") :soap-client)
      ((string= name "SOAPFAULT") :soap-fault)
      ((string= name "SOAPSERVER") :soap-server)
      ((string= name "SQLITE3STMT") :sqlite3-stmt)
      ((string= name "XSLTPROCESSOR") :xslt-processor))))

(defun %php85-runtime-object-new-ast (class-name args)
  (make-ast-call
   :func (make-ast-var :name (ecase (%php85-runtime-object-class-kind class-name)
                               (:dom-element (%php-runtime-symbol :dom-element-new))
                               (:dom-html-document (%php-runtime-symbol :dom-html-document-new))
                               (:pdo-sqlite (%php-runtime-symbol :pdo-sqlite-new))
                               (:soap-client (%php-runtime-symbol :soap-client-new))
                               (:soap-fault (%php-runtime-symbol :soap-fault-new))
                               (:soap-server (%php-runtime-symbol :soap-server-new))
                               (:sqlite3-stmt (%php-runtime-symbol :sqlite3-stmt-new))
                               (:xslt-processor (%php-runtime-symbol :xslt-processor-new))))
   :args args))

(defun php-parse-new (stream known-vars)
  "Parse 'new ClassName(args)' or 'new class [(args)] [extends/implements] { ... }'."
  (multiple-value-bind (tok rest) (php-consume stream) ; consume 'new'
    (declare (ignore tok))
    ;; Anonymous class: new class { ... }
    (when (%php-keyword-p rest :class)
      (return-from php-parse-new
        (%php-parse-anonymous-class (cdr rest) known-vars)))
    (multiple-value-bind (qualified-name rest2) (php-parse-qualified-name rest)
      (let ((class-name (php-ident-sym (php-resolve-qualified-name qualified-name :class))))
        ;; `new C` without parentheses is legal PHP, equivalent to `new C()`.
        (multiple-value-bind (args rest3 kv3)
            (if (eq (php-peek-type rest2) :T-LPAREN)
                (php-parse-arglist rest2 known-vars)
                (values nil rest2 known-vars))
          (when (%php-spl-builtin-class-p class-name)
            (return-from php-parse-new
              (values (%php-spl-new-ast class-name args) rest3 kv3)))
          (when (%php-fiber-class-p class-name)
            (return-from php-parse-new
              (values (%php-fiber-new-ast args) rest3 kv3)))
          (when (%php-uri-class-kind class-name)
            (return-from php-parse-new
              (values (%php-uri-new-ast class-name args) rest3 kv3)))
          (when (%php-reflection-object-class-kind class-name)
            (return-from php-parse-new
              (values (%php-reflection-new-ast class-name args) rest3 kv3)))
          (when (%php85-runtime-object-class-kind class-name)
            (return-from php-parse-new
              (values (%php85-runtime-object-new-ast class-name args) rest3 kv3)))
          ;; new C(args): allocate the instance (properties default-init from their
          ;; initforms), then run __construct($this, args) via %php-construct, and
          ;; yield the instance. (Previously the args were passed as :ARGn CLOS
          ;; initargs — which the class rejected — and the constructor never ran.)
          (let ((inst-sym (gensym "PHP-INST-")))
            (values (make-ast-let
                     :bindings (list (cons inst-sym
                                           (make-ast-make-instance
                                            :class (make-ast-var :name class-name)
                                            :initargs nil)))
                     :body (list
                            ;; Run __construct($this, args) only if the class defines
                            ;; it. The call uses the normal method-dispatch (vm-call)
                            ;; path, with the instance as the implicit $this first arg.
                            (make-ast-if
                             :cond (make-ast-call
                                    :func (make-ast-var :name (%php-runtime-symbol :has-method))
                                    :args (list (make-ast-var :name inst-sym)
                                                (make-ast-quote
                                                 :value (php-ident-sym "__construct"))))
                             :then (make-ast-call
                                    :func (make-ast-slot-value
                                           :object (make-ast-var :name inst-sym)
                                           :slot (php-ident-sym "__construct"))
                                    :args (cons (make-ast-var :name inst-sym) args))
                             :else (make-ast-quote :value nil))
                            (make-ast-var :name inst-sym)))
                    rest3 kv3)))))))
(eval-when (:load-toplevel :execute)
  (register-php-expression-keyword-parser :new #'php-parse-new)
  (register-php-expression-static-member-lowerer
   #'%php-class-static-member-lowerer))
