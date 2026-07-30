;;;; parser-trait-test.lisp — src/parser-trait.lisp — trait declarations and class-use-trait.

(in-package :cl-cc-php/test)

(describe "PHP traits"

;;; ─── Helpers (reuse %php-first from helpers-parser.lisp) ────────────────────

;;; ─── Trait Definition ────────────────────────────────────────────────────────

(it-sequential "php-trait-definition-produces-ast-defclass"
  (let ((ast (first (cl-cc/php:parse-php-source "<?php trait Greetable { }"))))
    (expect (cl-cc/ast:ast-defclass-p ast) :to-be-truthy)
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)))

(it-sequential "php-trait-name-is-upcased"
  (let ((ast (first (cl-cc/php:parse-php-source "<?php trait HasTimestamps { }"))))
    (expect (symbol-name (cl-cc/ast:ast-defclass-name ast)) :to-equal "HASTIMESTAMPS")))

(it-sequential "php-trait-with-method-produces-slot-def"
  (let* ((ast   (first (cl-cc/php:parse-php-source
                        "<?php trait Greetable { public function greet() { return 'hi'; } }")))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (plusp (length slots)) :to-be-truthy)
    (expect (every #'cl-cc/ast:ast-slot-def-p slots) :to-be-truthy)))

(it-sequential "php-trait-method-name-is-upcased"
  (let* ((ast   (first (cl-cc/php:parse-php-source
                        "<?php trait Greetable { public function greet() { return 'hello'; } }")))
         (slot  (first (cl-cc/ast:ast-defclass-slots ast))))
    (expect (symbol-name (cl-cc/ast:ast-slot-name slot)) :to-equal "GREET")))

(it-sequential "php-trait-with-abstract-method"
  (let* ((ast   (first (cl-cc/php:parse-php-source
                        "<?php trait HasLogger { abstract public function log(string $msg): void; }")))
         (slots (cl-cc/ast:ast-defclass-slots ast)))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)
    (expect (plusp (length slots)) :to-be-truthy)))

(it-sequential "php-trait-no-superclasses"
  (let ((ast (first (cl-cc/php:parse-php-source "<?php trait Mixin { }"))))
    (expect (cl-cc/ast:ast-defclass-superclasses ast) :to-be-null)))

;;; ─── Class Using a Trait ─────────────────────────────────────────────────────
;;;
;;; %PHP-MERGE-ALL-TRAIT-MEMBERS (a whole-program pass PARSE-PHP-SOURCE applies after
;;; every top-level form is parsed) replaces each class's trait-use marker slot-def
;;; with the actual members of the traits it names, so by the time these tests see the
;;; returned AST, the marker itself is gone from AST-DEFCLASS-SLOTS — merged into real
;;; member slot-defs instead. The same TRAIT-NAMES/INSTEADOF/ALIAS metadata these tests
;;; check is also independently recorded into *PHP-TRAIT-APPLICATIONS* (keyed by class
;;; name, one entry pushed per `use' clause) as a side effect of parsing, unaffected by
;;; the later merge — that is what these tests read instead.

(it-sequential "php-class-use-single-trait-produces-use-slot"
  (let* ((class (second (cl-cc/php:parse-php-source
                         "<?php trait Greetable { } class Greeter { use Greetable; }")))
         (application (first (gethash "GREETER" cl-cc/php::*php-trait-applications*))))
    (expect (cl-cc/ast:ast-defclass-p class) :to-be-truthy)
    (expect application :to-be-truthy)))

(it-sequential "php-class-use-single-trait-records-trait-name"
  (cl-cc/php:parse-php-source
   "<?php trait Greetable { } class Greeter { use Greetable; }")
  (let* ((application (first (gethash "GREETER" cl-cc/php::*php-trait-applications*)))
         (names (getf application :trait-names)))
    (expect (= 1 (length names)) :to-be-truthy)
    (expect (symbol-name (first names)) :to-equal "GREETABLE")))

;;; ─── Multiple Traits ─────────────────────────────────────────────────────────

(it-sequential "php-class-use-multiple-traits"
  (cl-cc/php:parse-php-source
   "<?php trait A { } trait B { } class MultiUseC { use A, B; }")
  (let* ((application (first (gethash "MULTIUSEC" cl-cc/php::*php-trait-applications*)))
         (names (getf application :trait-names)))
    (expect (= 2 (length names)) :to-be-truthy)
    (expect (find "A" names :key #'symbol-name :test #'string=) :to-be-truthy)
    (expect (find "B" names :key #'symbol-name :test #'string=) :to-be-truthy)))

;;; ─── Conflict Resolution: insteadof ─────────────────────────────────────────

(it-sequential "php-trait-insteadof-conflict-resolution"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    trait B { public function hello() { return 'B'; } }
    class InsteadofC { use A, B { A::hello insteadof B; } }")
  (let* ((application (first (gethash "INSTEADOFC" cl-cc/php::*php-trait-applications*)))
         (insteadof-list (getf application :insteadof)))
    (expect (plusp (length insteadof-list)) :to-be-truthy)
    (let ((entry (first insteadof-list)))
      (expect (symbol-name (getf entry :method)) :to-equal "HELLO")
      (expect (symbol-name (getf entry :from)) :to-equal "A"))))

(it-sequential "php-trait-insteadof-records-excluded-traits"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    trait B { public function hello() { return 'B'; } }
    class InsteadofExcludeC { use A, B { A::hello insteadof B; } }")
  (let* ((application (first (gethash "INSTEADOFEXCLUDEC" cl-cc/php::*php-trait-applications*)))
         (insteadof-list (getf application :insteadof))
         (excluded       (getf (first insteadof-list) :exclude)))
    (expect (find "B" excluded :key #'symbol-name :test #'string=) :to-be-truthy)))

;;; ─── Method Aliasing: as ─────────────────────────────────────────────────────

(it-sequential "php-trait-as-alias-records-alias-name"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    class AliasNameC { use A { A::hello as hi; } }")
  (let* ((application (first (gethash "ALIASNAMEC" cl-cc/php::*php-trait-applications*)))
         (alias-list (getf application :alias)))
    (expect (plusp (length alias-list)) :to-be-truthy)
    (let ((entry (first alias-list)))
      (expect (symbol-name (getf entry :alias)) :to-equal "HI"))))

(it-sequential "php-trait-as-alias-records-source-method"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    class AliasSourceC { use A { A::hello as hi; } }")
  (let* ((application (first (gethash "ALIASSOURCEC" cl-cc/php::*php-trait-applications*)))
         (entry (first (getf application :alias))))
    (expect (symbol-name (getf entry :method)) :to-equal "HELLO")))

;;; ─── Visibility Change ───────────────────────────────────────────────────────

(it-sequential "php-trait-as-visibility-change"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    class VisChangeC { use A { hello as protected; } }")
  (let* ((application (first (gethash "VISCHANGEC" cl-cc/php::*php-trait-applications*)))
         (entry (first (getf application :alias))))
    (expect (getf entry :vis) :to-be :protected)))

(it-sequential "php-trait-as-visibility-and-alias"
  (cl-cc/php:parse-php-source
   "<?php trait A { public function hello() { return 'A'; } }
    class VisAliasC { use A { A::hello as protected greeting; } }")
  (let* ((application (first (gethash "VISALIASC" cl-cc/php::*php-trait-applications*)))
         (entry (first (getf application :alias))))
    (expect (getf entry :vis) :to-be :protected)
    (expect (symbol-name (getf entry :alias)) :to-equal "GREETING")))

;;; ─── Trait Registry ──────────────────────────────────────────────────────────

(it-sequential "php-trait-definition-registers-methods"
  (cl-cc/php:parse-php-source
   "<?php trait RegisterMe { public function act() { return 1; } }")
  (let ((registry-entry (gethash "REGISTERME" cl-cc/php:*php-trait-registry*)))
    (expect (listp registry-entry) :to-be-truthy)
    (expect (plusp (length registry-entry)) :to-be-truthy)))

(it-sequential "php-trait-is-supported-by-check"
  (let ((ast (first (cl-cc/php:parse-php-source "<?php trait Mixin { }"))))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)
    ;; Must not signal an error — traits are supported
    (expect (cl-cc/php:php-check-supported-forms (list ast)) :to-be-truthy)))

(it-sequential "php-trait-with-property"
  (let* ((ast   (first (cl-cc/php:parse-php-source
                        "<?php trait HasName { public string $name; }")))
         (slots (cl-cc/ast:ast-defclass-slots ast))
         (prop  (first slots)))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)
    (expect (cl-cc/ast:ast-slot-def-p prop) :to-be-truthy)
    ;; Property slot names use the SAME symbol convention as member access
    ;; ($obj->name interns via php-ident-sym, upcased), so the declared slot name
    ;; matches how it is read/written. ($name -> NAME.) Without this they mismatched
    ;; and $obj->name raised "slot NAME is missing".
    (expect (symbol-name (cl-cc/ast:ast-slot-name prop)) :to-equal "NAME")))

(it-sequential "php-trait-multiple-methods"
  (let* ((ast   (first (cl-cc/php:parse-php-source
                        "<?php trait Multi {
                           public function foo() { return 1; }
                           public function bar() { return 2; }
                           public function baz() { return 3; }
                         }")))
         (slots (cl-cc/ast:ast-defclass-slots ast))
         (names (mapcar (lambda (s) (symbol-name (cl-cc/ast:ast-slot-name s))) slots)))
    (expect (cl-cc/ast:ast-defclass-php-kind ast) :to-be :trait)
    (expect (= 3 (length slots)) :to-be-truthy)
    (expect (member "FOO" names :test #'string=) :to-be-truthy)
    (expect (member "BAR" names :test #'string=) :to-be-truthy)
    (expect (member "BAZ" names :test #'string=) :to-be-truthy)))

(it-sequential "php-class-use-trait-with-no-conflict-block"
  (cl-cc/php:parse-php-source
   "<?php trait Simple { public function act() { return 1; } }
    class Worker { use Simple; }")
  (let* ((application (first (gethash "WORKER" cl-cc/php::*php-trait-applications*))))
    (expect application :to-be-truthy)
    (expect (getf application :insteadof) :to-be-null)))


  )
