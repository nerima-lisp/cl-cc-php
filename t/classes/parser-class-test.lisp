(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  (it-sequential "php-parser-trait-is-supported-by-check"
  (let ((ast (%php-first "<?php trait T { public $x; }")))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)
    (expect (cl-cc/php:php-check-supported-forms (list ast)) :to-be-truthy)))
  (it-sequential "php-parser-interface-is-supported-by-check"
  (let ((ast (%php-first "<?php interface I {}")))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :interface)
    (expect (cl-cc/php:php-check-supported-forms (list ast)) :to-be-truthy)))
  (it-sequential "php-parser-unit-enum-cases"
  (let* ((form (%php-first "<?php enum Suit { case Hearts; case Diamonds; }"))
         ;; An enum now lowers to (progn defclass (link-cases)); unwrap the defclass.
         (ast (if (cl-cc/ast:ast-progn-p form) (first (cl-cc/ast:ast-progn-forms form)) form))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :enum)
    (expect (cl-cc/ast:ast-defclass-php-enum-type ast) :to-be-null)
    (expect (mapcar (lambda (slot) (symbol-name (cl-cc/ast:ast-slot-name slot))) slots) :to-equal '("HEARTS" "DIAMONDS"))
    (expect (every (lambda (slot)
                          (and (eq :class (cl-cc/ast:ast-slot-allocation slot))
                               (getf (cl-cc/ast:ast-imports slot) :php-enum-case)))
                        slots) :to-be-truthy)
    (expect (mapcar (lambda (case) (symbol-name (getf case :name)))
                          (cl-cc/ast:ast-defclass-php-enum-cases ast)) :to-equal '("HEARTS" "DIAMONDS"))
    (cl-cc/php:php-check-supported-forms (list ast))))
  (it-sequential "php-parser-backed-enum-cases"
  (let* ((form (%php-first "<?php enum Status: int { case Draft = 0; case Published = 1; }"))
         (ast (if (cl-cc/ast:ast-progn-p form) (first (cl-cc/ast:ast-progn-forms form)) form))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :enum)
    (expect (cl-cc/ast:ast-defclass-php-enum-type ast) :to-be :int)
    (expect (= 2 (length slots)) :to-be-truthy)
    (expect (every (lambda (slot)
                          (cl-cc/ast:ast-call-p (cl-cc/ast:ast-slot-initform slot)))
                        slots) :to-be-truthy)))
  (it-sequential "php-parser-enum-implements-methods-traits-and-constants"
  (let* ((form (%php-first "<?php enum Status implements JsonSerializable { use HasLabels; const FOO = 'x'; public function label() { return 'ok'; } case Draft = 0; }"))
         (ast (if (cl-cc/ast:ast-progn-p form) (first (cl-cc/ast:ast-progn-forms form)) form))
         (slot-names (mapcar (lambda (slot) (symbol-name (cl-cc/ast:ast-slot-name slot)))
                             (cl-cc/ast:ast-defclass-slots ast))))
    (expect (member "JSONSERIALIZABLE"
                         (mapcar #'symbol-name (cl-cc/ast:ast-defclass-superclasses ast))
                         :test #'string=) :to-be-truthy)
    (expect (member "FOO" slot-names :test #'string=) :to-be-truthy)
    (expect (member "LABEL" slot-names :test #'string=) :to-be-truthy)
    (expect (member "DRAFT" slot-names :test #'string=) :to-be-truthy)))
  (it-sequential "php-parser-enum-static-builtins"
  (let* ((asts (cl-cc/php:parse-php-source "<?php enum Status: int { case Draft = 0; case Published = 1; } $x = Status::from(1); $y = Status::tryFrom(99); $z = Status::cases();"))
         ;; enum defclass is first; let-x is second (wraps y and z in its body chain)
         (let-x  (second asts))
         (let-y  (first (cl-cc/ast:ast-let-body let-x)))
         (let-z  (first (cl-cc/ast:ast-let-body let-y)))
         (from-call     (cdr (first (cl-cc/ast:ast-let-bindings let-x))))
         (try-from-call (cdr (first (cl-cc/ast:ast-let-bindings let-y))))
         (cases-call    (cdr (first (cl-cc/ast:ast-let-bindings let-z)))))
    (expect (%php-call-name from-call) :to-equal "%PHP-ENUM-FROM")
    (expect (%php-call-name try-from-call) :to-equal "%PHP-ENUM-TRY-FROM")
    (expect (%php-call-name cases-call) :to-equal "%PHP-ENUM-CASES")))
  (it-sequential "php-parser-class-typed-properties"
  (let* ((ast (%php-first "<?php class User { public int $id; private ?string $name; readonly public int|float $score; }"))
          (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (= 3 (length slots)) :to-be-truthy)
    (expect (mapcar #'cl-cc/ast:ast-slot-type slots) :to-equal '("int" "?string" "int|float"))
    (expect (member :readonly (getf (cl-cc/ast:ast-imports (third slots)) :php-modifiers)) :to-be-truthy)))
  (it-sequential "php-parser-readonly-class-marks-instance-properties"
  (let* ((ast (%php-first "<?php readonly class User { public int $id; public static int $count; public function name() { return 1; } }"))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (labels ((slot (name)
               (find name slots
                     :key (lambda (slot)
                            (symbol-name (cl-cc/ast:ast-slot-name slot)))
                     :test #'string=)))
      (let ((id (slot "ID"))
            (count (slot "COUNT"))
            (name (slot "NAME")))
        (expect (getf (cl-cc/ast:ast-imports id) :readonly-p) :to-be-truthy)
        (expect (member :readonly (getf (cl-cc/ast:ast-imports id) :php-modifiers)) :to-be-truthy)
        (expect (getf (cl-cc/ast:ast-imports count) :readonly-p) :to-be-falsy)
        (expect (getf (cl-cc/ast:ast-imports name) :readonly-p) :to-be-falsy)))))
  (it-sequential "php-parser-class-typed-constants"
  (let* ((ast (%php-first "<?php class C { const int FOO = 1; const BAR = 'x'; }"))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (= 2 (length slots)) :to-be-truthy)
    (expect (mapcar (lambda (slot)
                                             (symbol-name (cl-cc/ast:ast-slot-name slot)))
                                           slots) :to-equal '("FOO" "BAR"))
    (expect (mapcar #'cl-cc/ast:ast-slot-type slots) :to-equal '("int" nil))
     (expect (every (lambda (slot)
                           (and (eq :class (cl-cc/ast:ast-slot-allocation slot))
                                (getf (cl-cc/ast:ast-imports slot) :php-class-constant)))
                         slots) :to-be-truthy)))
  (it-sequential "php-parser-multiple-class-constants-in-one-declaration"
  (let* ((ast (%php-first "<?php class C { public const int FOO = 1, BAR = 2; }"))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (= 2 (length slots)) :to-be-truthy)
    (expect (mapcar (lambda (slot)
                            (symbol-name (cl-cc/ast:ast-slot-name slot)))
                          slots) :to-equal '("FOO" "BAR"))
    (expect (mapcar #'cl-cc/ast:ast-slot-type slots) :to-equal '("int" "int"))
    (expect (every (lambda (slot)
                          (and (eq :class (cl-cc/ast:ast-slot-allocation slot))
                               (member :public (getf (cl-cc/ast:ast-imports slot) :php-modifiers))
                               (getf (cl-cc/ast:ast-imports slot) :php-class-constant)))
                        slots) :to-be-truthy)))
  (it-sequential "php-parser-constructor-promotion"
  (let ((ast (%php-first
              "<?php class P { public function __construct(public int $x, private string $y) {} }")))
    (expect (cl-cc/ast:ast-defclass-p ast) :to-be-truthy)))
  (it-sequential "php-parser-constructor-promotion-readonly"
  (let ((ast (%php-first
              "<?php class P { public function __construct(int $a, public readonly ?string $b = null) {} }")))
    (expect (cl-cc/ast:ast-defclass-p ast) :to-be-truthy)))
  (it-sequential "php-parser-anonymous-class"
  (let ((ast (%php-first "<?php $o = new class { public $x = 1; };")))
    (expect ast :to-be-truthy)))
  (it-sequential "php-parser-anonymous-class-extends-ctor"
  (let ((ast (%php-first
              "<?php $o = new class(5) extends Base { public function __construct(public int $n) {} };")))
    (expect ast :to-be-truthy))))

(describe "PHP grammar CST class constructors"
(it-sequential "parses new ClassName(args) as a :new interior node"
  (let ((cst (cl-cc/php/classes:php-cst-parse-new (%php-cst-ts "<?php new Foo(1, 2)"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :new)
    ;; new-keyword token + class-name token + 2 arg CSTs
    (expect (length (cl-cc/parse:cst-interior-children cst)) :to-equal 4)))

(it-sequential "parses new ClassName with no arglist at all"
  (let ((cst (cl-cc/php/classes:php-cst-parse-new (%php-cst-ts "<?php new Foo"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :new)
    (expect (length (cl-cc/parse:cst-interior-children cst)) :to-equal 2))))
