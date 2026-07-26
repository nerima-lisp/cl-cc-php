;;;; parser-property-hooks-e2e-test.lisp — src/parser-property-hooks.lisp, run end to end.

(in-package :cl-cc-php/test)

;;; NOTE: property hooks (public $x { get => ...; set(...) => ...; }) parse
;;; into the right AST shape (synthesized __get_X/__set_X method slots — see
;;; parser-php84-features-test.lisp) but ordinary $obj->x property reads/writes are
;;; not currently wired to dispatch through those synthesized methods, so
;;; hook bodies never actually run. No end-to-end coverage is added for that
;;; path here since it isn't functional yet.

(describe "PHP 8.4 asymmetric visibility (end-to-end)"

(it-sequential "public private(set) allows external reads of the property"
  (expect (%php-run-capture
           "<?php class Point { public private(set) int $x = 5; } $p = new Point(); echo $p->x;")
          :to-equal "5"))

  )

(describe "PHP 8.1 intersection types (end-to-end)"

(it-sequential "a function typed with an intersection type accepts a matching object"
  (expect (%php-run-capture
           "<?php interface Countable2 { function count2(); } interface Stringable2 { function __toString(); } class Both implements Countable2, Stringable2 { function count2() { return 3; } function __toString() { return 's'; } } function f(Countable2&Stringable2 $x) { return $x->count2(); } $o = new Both(); echo f($o);")
          :to-equal "3"))

  )
