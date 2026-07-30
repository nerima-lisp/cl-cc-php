;;;; parser-trait.lisp — PHP Trait declaration and use-trait parser
;;;;
;;;; Implements:
;;;;   trait Greetable { method-list }
;;;;   use TraitA, TraitB [{ insteadof/as block }] ;
;;;;
;;;; AST mapping, at parse time:
;;;;   trait Foo { ... }  → ast-defclass with :php-kind :trait, methods as slot-defs
;;;;   use A, B { ... }   → ast-slot-def with :php-trait-use t / :php-trait-uses list
;;;;                         conflict resolution stored in :php-trait-insteadof / :php-trait-alias
;;;;
;;;; PARSE-PHP-SOURCE then runs %PHP-MERGE-ALL-TRAIT-MEMBERS as a whole-program pass:
;;;; every class's trait-use marker is replaced with the actual member slot-defs of the
;;;; traits it names (with insteadof-resolved conflicts, and a clear error for conflicts
;;;; it does not resolve), so the marker itself never reaches codegen.

(in-package :cl-cc/php)

;;; ─── Trait Registry ─────────────────────────────────────────────────────────

(defvar *php-trait-registry* (make-hash-table :test #'equal)
  "Maps trait name strings to their member slot-def lists.
Read by %PHP-MERGE-TRAIT-MEMBERS to copy each used trait's members into the
classes that use it.")

;;; ─── Trait Application Runtime Record ──────────────────────────────────────

(defvar *php-trait-applications* (make-hash-table :test #'equal)
  "Maps class-name strings to lists of trait application plists.
Each plist has :trait-names, :insteadof, :alias entries.")

(defun %php-apply-traits (class-name trait-names insteadof-list alias-list)
  "Record trait usage for CLASS-NAME.
TRAIT-NAMES  — list of trait name symbols being used.
INSTEADOF-LIST — list of (method-sym trait-sym insteadof-sym ...) plists.
ALIAS-LIST   — list of (original-sym alias-sym) plists.
Stores into *php-trait-applications*, consulted by reflection
(%php-reflection-class-trait-symbols) for class_uses()/getTraits()."
  (let ((class-key (if (symbolp class-name)
                       (symbol-name class-name)
                       class-name)))
    (push (list :trait-names trait-names
                :insteadof  insteadof-list
                :alias      alias-list)
          (gethash class-key *php-trait-applications* nil))))

(defun %php-record-class-trait-uses (class-name slots)
  "Record every trait-use metadata slot found in SLOTS for CLASS-NAME."
  (dolist (slot slots)
    (when (ast-slot-def-p slot)
      (let ((imports (ast-imports slot)))
        (when (getf imports :php-trait-use)
          (%php-apply-traits class-name
                             (getf imports :php-trait-names)
                             (getf imports :php-insteadof)
                             (getf imports :php-alias)))))))

(defun %php-merge-all-trait-members (stmts)
  "Walk top-level PHP AST nodes STMTS and replace each class's trait-use
marker slot-defs with the actual members of the traits it names — see
%PHP-MERGE-TRAIT-MEMBERS for the merge/conflict-resolution rules. Runs as a
whole-program pass, not inline during class parsing, for two reasons: classes
using a trait declared later in the same source are still resolved correctly
(*PHP-TRAIT-REGISTRY* is fully populated by the time any pass over STMTS
runs), and t/parser-trait-test.lisp's parser-level tests — which check that
`use ... { insteadof/as }' syntax parses into the correct raw metadata — keep
seeing that raw, pre-merge marker, unaffected by what a later pass does with
it.

Trait declarations composing other traits (a trait's own `use' clause) are
not handled; :CLASS- and :ENUM-kind AST-DEFCLASS nodes are merged into (PHP
enums may `use' a trait exactly like a class can — an enum's own methods are
themselves stored the same way, as slot-defs on an AST-DEFCLASS). An enum
declaration's AST-DEFCLASS is not a bare top-level form the way a class's
is — %PHP-PARSE-CLASSLIKE wraps it in an AST-PROGN alongside a
%PHP-ENUM-FINALIZE call, so each top-level statement is checked for a
directly-nested AST-DEFCLASS, not just for being one itself. A merged-in
trait method also needs its :ALLOCATION forced to :CLASS when the target is
an enum, mirroring %PHP-PARSE-CLASSLIKE's own fixup for methods declared
directly in the enum body — enum methods dispatch through the shared enum
class object, not per-instance, so a trait method copied in with its
original :INSTANCE allocation (correct for a class, wrong for an enum) left
$case->method() unable to find it."
  (flet ((merge-into (defclass)
           (when (member (ast-defclass-php-kind defclass) '(:class :enum))
             (let ((members (%php-merge-trait-members (ast-defclass-slots defclass))))
               (when (eq (ast-defclass-php-kind defclass) :enum)
                 (dolist (member members)
                   (when (and (ast-slot-def-p member) (ast-defun-p (ast-slot-initform member)))
                     (setf (ast-slot-allocation member) :class))))
               (setf (ast-defclass-slots defclass) members)))))
    (dolist (stmt stmts)
      (cond
        ((ast-defclass-p stmt) (merge-into stmt))
        ((ast-progn-p stmt) (mapc (lambda (form)
                                    (when (ast-defclass-p form) (merge-into form)))
                                  (ast-progn-forms stmt))))))
  stmts)

(defun %php-trait-use-marker-p (slot)
  "True when SLOT is the internal marker %PHP-PARSE-USE-TRAIT-STMT emits for a
`use TraitA, TraitB;' clause in a class body — not a real property or method."
  (and (ast-slot-def-p slot) (getf (ast-imports slot) :php-trait-use)))

(defun %php-slot-renamed (slot new-name)
  "Return a copy of member SLOT with its name changed to NEW-NAME."
  (let ((copy (copy-structure slot)))
    (setf (ast-slot-name copy) new-name)
    copy))

(defun %php-slot-with-visibility (slot vis)
  "Return a copy of member SLOT with its :PHP-MODIFIERS visibility keyword
(one of :public/:protected/:private) replaced by VIS."
  (let* ((copy (copy-structure slot))
         (imports (ast-imports copy))
         (modifiers (remove-if (lambda (m) (member m '(:public :protected :private)))
                               (getf imports :php-modifiers))))
    (setf (ast-imports copy)
          (list* :php-modifiers (cons vis modifiers)
                 (loop for (key value) on imports by #'cddr
                       unless (eq key :php-modifiers)
                         append (list key value))))
    copy))

(defun %php-apply-trait-aliases (members alias-list)
  "Apply ALIAS-LIST's `as' clauses against MEMBERS, a member-name -> slot-def
hash table built by %PHP-MERGE-TRAIT-MEMBERS (mutated in place). Returns the
list of newly-created alias names, so the caller can append them to its
member order — MEMBERS already has the right slot-def for every name that
was already there.

A clause with an :ALIAS creates an additional, renamed copy of the source
member (also visibility-adjusted, if :VIS is also given) under the new name;
the original name is untouched and stays callable. A clause with only :VIS
changes the existing member's visibility in place. A clause naming a member
no used trait actually defines is silently ignored."
  (let ((new-names nil))
    (dolist (entry alias-list)
      (let* ((name (getf entry :method))
             (source (gethash name members))
             (vis (getf entry :vis))
             (alias (getf entry :alias)))
        (when source
          (cond
            (alias
             (setf (gethash alias members)
                   (if vis
                       (%php-slot-with-visibility (%php-slot-renamed source alias) vis)
                       (%php-slot-renamed source alias)))
             (push alias new-names))
            (vis
             (setf (gethash name members) (%php-slot-with-visibility source vis)))))))
    (nreverse new-names)))

(defun %php-merge-trait-members (slots)
  "Replace each trait-use marker in SLOTS with the actual member slot-defs of
the traits it names, looked up from *PHP-TRAIT-REGISTRY*.

A member name defined by only one used trait is copied in as-is. A member
name defined by more than one used trait is resolved by any matching
INSTEADOF clause (`TraitA::member insteadof TraitB;' keeps TraitA's version,
drops TraitB's); a collision INSTEADOF does not resolve signals a clear
error, matching real PHP's fatal \"has not been applied, because there are
collisions\" instead of silently picking one trait's version. Each ALIAS
(`as') clause is then applied by %PHP-APPLY-TRAIT-ALIASES — see its
docstring for what a rename vs. a visibility-only change does."
  (loop for slot in slots
        append
        (if (%php-trait-use-marker-p slot)
            (let* ((imports (ast-imports slot))
                   (insteadof (getf imports :php-insteadof))
                   (members (make-hash-table :test #'eq))
                   (order nil))
              (dolist (trait-sym (getf imports :php-trait-names))
                (dolist (member (gethash (string-upcase (symbol-name trait-sym))
                                         *php-trait-registry*))
                  (let* ((name (ast-slot-name member))
                         (resolution (find name insteadof :key (lambda (e) (getf e :method)))))
                    (cond
                      (resolution
                       (when (eq trait-sym (getf resolution :from))
                         (unless (gethash name members) (push name order))
                         (setf (gethash name members) member)))
                      ((gethash name members)
                       (%php-unsupported
                        (format nil "~A is defined by more than one used trait; add an ~
                                     `insteadof' clause to resolve the conflict"
                                name)))
                      (t
                       (push name order)
                       (setf (gethash name members) member))))))
              (let ((new-names (%php-apply-trait-aliases members (getf imports :php-alias))))
                (mapcar (lambda (name) (gethash name members))
                        (append (nreverse order) new-names))))
            (list slot))))

;;; ─── Conflict Resolution Block Parser ───────────────────────────────────────
;;;
;;; Parses the optional `{ insteadof/as clauses }` block that follows a
;;; use-trait list.  Returns (values insteadof-list alias-list rest-stream).
;;;
;;; Grammar (simplified):
;;;   conflict-block  ::= '{' conflict-stmt* '}'
;;;   conflict-stmt   ::= qualified '::' name 'insteadof' name (',' name)* ';'
;;;                      | qualified '::' name 'as' [visibility] [alias-name] ';'
;;;                      | name 'as' [visibility] alias-name ';'

(defun %php-parse-insteadof-targets (stream)
  "Consume comma-separated trait names after insteadof.
Returns (values name-sym-list rest)."
  (let ((names nil) (current stream))
    (loop
      (multiple-value-bind (qname rest) (php-parse-qualified-name current)
        (push (php-ident-sym (php-resolve-qualified-name qname :class)) names)
        (setf current rest))
      (unless (eq (php-peek-type current) :T-COMMA)
        (return))
      (setf current (cdr current)))
    (values (nreverse names) current)))

(defun %php-visibility-keyword-p (stream)
  "Return T when the current token is a visibility modifier keyword."
  (and (eq (php-peek-type stream) :T-KEYWORD)
       (member (php-peek-value stream)
               '(:public :protected :private) :test #'eq)))

(defun %php-parse-conflict-clause (stream insteadof-acc alias-acc)
  "Parse one insteadof-or-as clause.
Returns (values updated-insteadof updated-alias rest-stream).

Clause forms:
  TraitA::method insteadof TraitB, TraitC ;
  TraitA::method as alias ;
  TraitA::method as public ;        (visibility-only alias)
  method         as alias ;
  method         as public alias ;
"
  (multiple-value-bind (lhs-name lhs-rest) (php-parse-qualified-name stream)
    (let ((current lhs-rest))
      (cond
        ;; TraitA::method ...  ('::' is lexed as :T-DOUBLE-COLON, not :T-OP)
        ((eq (php-peek-type current) :T-DOUBLE-COLON)
         (setf current (cdr current))       ; consume ::
         (multiple-value-bind (method-tok method-rest) (php-expect :T-IDENT current)
           (setf current method-rest)
           (let ((trait-sym  (php-ident-sym (php-resolve-qualified-name lhs-name :class)))
                 (method-sym (php-ident-sym (php-tok-value method-tok))))
             (cond
               ;; TraitA::method insteadof TraitB, TraitC ;
               ((%php-keyword-p current :insteadof)
                (setf current (cdr current))
                (multiple-value-bind (excluded rest2)
                    (%php-parse-insteadof-targets current)
                  (values (cons (list :method method-sym
                                      :from   trait-sym
                                      :exclude excluded)
                                insteadof-acc)
                          alias-acc
                          (php-skip-semis rest2))))
               ;; TraitA::method as [visibility] [alias] ;
               ((%php-keyword-p current :as)
                (setf current (cdr current))
                (let ((vis nil) (alias nil))
                  (when (%php-visibility-keyword-p current)
                    (setf vis (php-peek-value current)
                          current (cdr current)))
                  (when (eq (php-peek-type current) :T-IDENT)
                    (multiple-value-bind (alias-tok rest2) (php-consume current)
                      (setf alias (php-ident-sym (php-tok-value alias-tok))
                            current rest2)))
                  (values insteadof-acc
                          (cons (list :method method-sym
                                      :from   trait-sym
                                      :alias  alias
                                      :vis    vis)
                                alias-acc)
                          (php-skip-semis current))))
               (t
                (error "PHP trait conflict block: expected insteadof or as after ~S::~S"
                       lhs-name (php-tok-value method-tok)))))))
        ;; Simple: method as [visibility] alias ;
        ((%php-keyword-p current :as)
         (setf current (cdr current))
         (let ((method-sym (php-ident-sym (php-resolve-qualified-name lhs-name :function)))
               (vis nil)
               (alias nil))
           (when (%php-visibility-keyword-p current)
             (setf vis (php-peek-value current)
                   current (cdr current)))
           (when (eq (php-peek-type current) :T-IDENT)
             (multiple-value-bind (alias-tok rest2) (php-consume current)
               (setf alias (php-ident-sym (php-tok-value alias-tok))
                     current rest2)))
           (values insteadof-acc
                   (cons (list :method method-sym
                               :from   nil
                               :alias  alias
                               :vis    vis)
                         alias-acc)
                   (php-skip-semis current))))
        (t
         (error "PHP trait conflict block: unrecognized clause near ~S" (php-peek stream)))))))

(defun %php-parse-trait-conflict-block (stream)
  "Parse an optional `{ ... }` conflict-resolution block after a use-trait list.
Returns (values insteadof-list alias-list rest-stream).
If no block is present (semicolon follows), returns empty lists."
  (cond
    ;; No conflict block — simple use A, B ;
    ((eq (php-peek-type stream) :T-SEMI)
     (values nil nil (cdr stream)))
    ;; Conflict block — use A, B { ... }
    ((eq (php-peek-type stream) :T-LBRACE)
     (let ((current (cdr stream))             ; consume {
           (insteadof nil)
           (alias nil))
       (loop
         (setf current (php-skip-semis current))
         (when (or (php-at-eof-p current)
                   (eq (php-peek-type current) :T-RBRACE))
           (return))
         (multiple-value-bind (new-insteadof new-alias rest2)
             (%php-parse-conflict-clause current insteadof alias)
           (setf insteadof new-insteadof
                 alias     new-alias
                 current   rest2)))
       (values (nreverse insteadof)
               (nreverse alias)
               (%php-consume-expected :T-RBRACE current))))
    (t
     (error "PHP parse error: expected ; or { after use-trait list, got ~S"
            (php-peek stream)))))

;;; ─── Use-Trait Statement ────────────────────────────────────────────────────

(defun %php-parse-use-trait-stmt (stream known-vars)
  "Parse `use TraitA, TraitB [{ insteadof/as block }] ;` inside a class body.
STREAM starts after the `use` keyword has been consumed.
Returns (values ast-slot-def rest-stream known-vars).

The returned ast-slot-def carries:
  :php-trait-use    t
  :php-trait-names  list-of-trait-syms
  :php-insteadof    list-of-insteadof-plists
  :php-alias        list-of-alias-plists"
  (declare (ignore known-vars))
  (let ((current stream)
        (trait-syms nil))
    ;; Collect comma-separated trait names.
    (loop
      (multiple-value-bind (qname rest) (php-parse-qualified-name current)
        (push (php-ident-sym (php-resolve-qualified-name qname :class)) trait-syms)
        (setf current rest))
      (unless (eq (php-peek-type current) :T-COMMA)
        (return))
      (setf current (cdr current)))
    (let ((names (nreverse trait-syms)))
      (multiple-value-bind (insteadof alias rest2)
          (%php-parse-trait-conflict-block current)
        (let ((slot (make-ast-slot-def
                     :name (gensym "PHP-USE-TRAIT-")
                     :allocation :class
                     :imports (list :php-trait-use   t
                                    :php-trait-names  names
                                    :php-insteadof    insteadof
                                    :php-alias        alias))))
          (values slot rest2 nil))))))
