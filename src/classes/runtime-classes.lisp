(in-package #:cl-cc/php/classes)

(defun %php-clone-with (instance overrides)
  "Apply PHP 8.5 clone-with property OVERRIDES to already-cloned INSTANCE."
  (unless (hash-table-p overrides)
    (%php-throw 'type-error "clone-with overrides must be an array"))
  (dolist (pair (%php-array-pairs overrides) instance)
    (let* ((slot (%php-clone-with-slot (car pair)))
           (class (and (cl-cc/vm:%vm-vector-instance-p instance)
                       (aref instance 0)))
           (index (and class
                       (cl-cc/vm:%vm-slot-vector-index class slot))))
      (unless (and index (< index (length instance)))
        (%php-throw 'error
                    (format nil "The slot ~S is missing from the cloned object"
                            slot)))
      (setf (aref instance index) (cdr pair)))))

(defun %php-clone-with-slot (property)
  "Map a PHP clone-with property key to the VM slot symbol used by class fields."
  (intern (string-upcase (%php-stringify property)) (find-package :cl-cc/php)))

(defun %php-clone (instance)
  "Return PHP's shallow object clone. The parser is responsible for invoking a
class-defined __clone method on the copied object so the call stays inside the
normal VM method-dispatch path."
  (handler-case
      (cl-cc/vm:copy-instance instance)
    (error (condition)
      (error "Cannot clone non-object value ~S: ~A" instance condition))))

(defun %php-has-method (instance name-sym)
  "Return true when INSTANCE's class defines a slot/method named NAME-SYM. Used by
the `new C(args)' lowering to call __construct only when it exists — the call
itself runs through the normal method-dispatch (vm-call) path, so the constructor
executes in the right VM context."
  (and (cl-cc/vm:%vm-vector-instance-p instance)
       (let ((class (aref instance 0)))
         (and (hash-table-p class)
              (cl-cc/vm:%vm-slot-vector-index class name-sym)
              t))))

(defun %php-enum-make-case (enum-name case-name value)
  "Create a PHP enum case singleton payload.  `name' and `value' are stored under
STRING keys so $case->name / $case->value resolve through the slot-read string-
key fallback (a symbol key would require the runtime-interned property symbol to
land in the same package, which it does not reliably)."
  ;; :test #'equal — the slot-read string-key fallback looks up "name"/"value"
  ;; with a freshly built string, which is not EQ to the stored key; equal makes
  ;; both the string property keys and the keyword internal keys resolve.
  (let ((case (make-hash-table :test #'equal)))
    (setf (gethash :__php-enum-case__ case) t
          (gethash :__enum-name__ case) enum-name
          (gethash :__case-name__ case) case-name
          (gethash "value" case) value
          (gethash "name" case) (symbol-name case-name))
    case))

(defun %php-enum-case-p (value)
  "Return true when VALUE is a PHP enum case payload."
  (and (hash-table-p value) (gethash :__php-enum-case__ value)))

(defun %php-enum-finalize (enum-class)
  "Link each of ENUM-CLASS's case singletons to the class via :__class__ so that
$case->method() dispatches through the class.  (Enum methods are stored class-
allocated, so slot-read on a case whose __class__ is the enum class resolves
them.)  Returns ENUM-CLASS."
  (when (hash-table-p enum-class)
    (dolist (case (%php-enum-case-list enum-class))
      (setf (gethash :__class__ case) enum-class)))
  enum-class)

(defun %php-enum-case-list (enum-class)
  "Return ENUM-CLASS's case singleton payloads as a CL list (insertion order)."
  (check-type enum-class hash-table)
  (loop for slot-name in (gethash :__class-slots__ enum-class)
        for slot-value = (gethash slot-name enum-class)
        when (%php-enum-case-p slot-value)
          collect slot-value))

(defun %php-enum-cases (enum-class)
  "Return ENUM::cases() — a PHP ARRAY of the case singletons (so count(), foreach,
etc. work). The previous CL list broke count()/array builtins."
  (%php-list-to-array (%php-enum-case-list enum-class)))

(defun %php-enum-case-value (enum-case)
  "Return ENUM-CASE's backed value, or PHP null for unit cases."
  (check-type enum-case hash-table)
  (gethash "value" enum-case +php-null+))

(defun %php-enum-try-from (enum-class value)
  "Return the backed enum case from ENUM-CLASS matching VALUE, or PHP null."
  (or (find value (%php-enum-case-list enum-class)
            :key #'%php-enum-case-value
            :test #'%php-eq-strict)
      +php-null+))

(defun %php-enum-from (enum-class value)
  "Return the backed enum case from ENUM-CLASS matching VALUE, or signal a PHP ValueError."
  (let ((case (%php-enum-try-from enum-class value)))
    (if (%php-null-p case)
        (%php-throw 'value-error (format nil "No enum case for value ~S" value))
        case)))

;;; ─── Enum case accessors ────────────────────────────────────────────────────

(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :clone '%php-clone)
  (register-php-runtime-symbol :clone-with '%php-clone-with)
  (register-php-runtime-symbol :has-method '%php-has-method)
  (register-php-runtime-symbol :enum-cases '%php-enum-cases)
  (register-php-runtime-symbol :enum-from '%php-enum-from)
  (register-php-runtime-symbol :enum-try-from '%php-enum-try-from))

(in-package #:cl-cc/php/classes)

(defun %php-validate-override-tree (stmts)
  "Validate #[Override] attributes across the parsed AST tree."
  (let ((class-registry (%php-class-registry stmts)))
    (labels ((visit (node)
               (when (ast-defclass-p node)
                 (dolist (slot (ast-defclass-slots node))
                   (%php-validate-override-slot class-registry node slot)))
               (dolist (child (ast-children node))
                 (visit child))))
      (dolist (stmt stmts)
        (visit stmt))))
  stmts)

(defun %php-validate-override-slot (class-registry class-node slot)
  "Signal an error when SLOT's #[Override] attribute has no inherited target."
  (when (%php-member-override-attribute-p slot)
    (let ((kind (%php-member-kind slot))
          (member-name (ast-slot-name slot)))
      (unless (some (lambda (parent)
                      (cond ((gethash parent *php-interface-registry*)
                             (and (eq kind :method)
                                  (%php-interface-member-present-p parent member-name)))
                            ((gethash parent class-registry)
                             (%php-class-member-present-p class-registry parent member-name kind))
                            (t nil)))
                    (ast-defclass-superclasses class-node))
        (ast-error slot "#[Override] on ~A does not match an inherited ~A."
                   (symbol-name member-name)
                   (ecase kind
                     (:method "method")
                     (:property "property")
                     (:constant "class constant")))))))

(defun %php-class-registry (stmts)
  "Build a compile-time registry for all class-like nodes in STMTS."
  (let ((classes (make-hash-table :test #'equal)))
    (labels ((visit (node)
               (when (ast-defclass-p node)
                 (setf (gethash (ast-defclass-name node) classes) node))
               (dolist (child (ast-children node))
                 (visit child))))
      (dolist (stmt stmts)
        (visit stmt)))
    classes))

(defun %php-class-member-present-p (class-registry class-name member-name kind
                                    &optional (seen (make-hash-table :test #'equal)))
  "Return true when CLASS-NAME or one of its ancestors declares MEMBER-NAME."
  (unless (gethash class-name seen)
    (setf (gethash class-name seen) t)
    (let ((class-node (gethash class-name class-registry)))
      (when class-node
        (or (find-if (lambda (slot)
                       (and (ast-slot-def-p slot)
                            (eq (ast-slot-name slot) member-name)
                            (not (%php-member-private-p slot))
                            (ecase kind
                              (:method (ast-defun-p (ast-slot-initform slot)))
                              (:property (and (not (ast-defun-p (ast-slot-initform slot)))
                                              (not (getf (ast-imports slot)
                                                         :php-class-constant))))
                              (:constant (getf (ast-imports slot) :php-class-constant)))))
                     (ast-defclass-slots class-node))
            (some (lambda (parent)
                    (cond ((gethash parent *php-interface-registry*)
                           (and (eq kind :method)
                                (%php-interface-member-present-p parent member-name seen)))
                          ((gethash parent class-registry)
                           (%php-class-member-present-p
                            class-registry parent member-name kind seen))
                          (t nil)))
                  (ast-defclass-superclasses class-node)))))))

(defun %php-interface-member-present-p (interface-name member-name
                                        &optional (seen (make-hash-table :test #'equal)))
  "Return true when INTERFACE-NAME or one of its ancestors declares MEMBER-NAME."
  (unless (gethash interface-name seen)
    (setf (gethash interface-name seen) t)
    (let ((record (gethash interface-name *php-interface-registry*)))
      (when record
        (or (find member-name (getf record :methods)
                  :key (lambda (sig) (getf sig :name))
                  :test #'equal)
            (some (lambda (parent)
                    (%php-interface-member-present-p parent member-name seen))
                  (getf record :parents)))))))

(defun %php-member-private-p (slot)
  "Return true when SLOT is marked private."
  (member :private (getf (ast-imports slot) :php-modifiers) :test #'eq))

(defun %php-member-kind (slot)
  "Return SLOT's PHP member kind."
  (cond ((not (ast-slot-def-p slot)) nil)
        ((ast-defun-p (ast-slot-initform slot)) :method)
        ((getf (ast-imports slot) :php-class-constant) :constant)
        (t :property)))

(defun %php-member-override-attribute-p (slot)
  "Return SLOT's #[Override] attribute, if present."
  (find-if #'%php-override-attribute-p (%php-member-attributes slot)))

(defun %php-member-attributes (slot)
  "Return all PHP attributes attached to SLOT or its method body."
  (append (copy-list (%php-metadata-get (ast-imports slot)
                                        :php-attributes))
          (when (and (ast-slot-def-p slot)
                     (ast-defun-p (ast-slot-initform slot)))
            (copy-list (%php-metadata-get (ast-defun-declarations (ast-slot-initform slot))
                                          :php-attributes)))))

(defun %php-override-attribute-p (attribute)
  "Return true when ATTRIBUTE names #[Override]."
  (and (php-attribute-p attribute)
       (string-equal "Override"
                     (%php-attribute-short-name (php-attribute-name attribute)))))
