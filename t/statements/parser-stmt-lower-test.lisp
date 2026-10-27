(in-package :cl-cc/php/statements/test)

(describe "PHP statement parser tests"
  (it-sequential "php-parser-echo-lowers-to-output-write-call"
  (let ((ast (%php-first "<?php echo 42;")))
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (%php-call-name ast) :to-equal "%PHP-OUTPUT-WRITE")
    (let ((expr (first (cl-cc/ast:ast-call-args ast))))
      (expect (cl-cc/ast:ast-call-p expr) :to-be-truthy)
      (expect (%php-call-name expr) :to-equal "%PHP-CONCAT")
      (expect (typep (first (cl-cc/ast:ast-call-args expr)) 'cl-cc/ast:ast-int) :to-be-truthy))))
  ;;; ─── :return handler → ast-return-from ───────────────────────────────────

(it-sequential "php-parser-return-with-value-lowering"
  (let ((ast (%php-first "<?php return 1;")))
    (expect (typep ast 'cl-cc/ast:ast-return-from) :to-be-truthy)
    (expect (typep (cl-cc/ast:ast-return-from-value ast) 'cl-cc/ast:ast-int) :to-be-truthy)))
(it-sequential "php-parser-bare-return-has-nil-name"
  (let ((ast (%php-first "<?php return;")))
    (expect (typep ast 'cl-cc/ast:ast-return-from) :to-be-truthy)
    (expect (cl-cc/ast:ast-return-from-name ast) :to-be-null)))
;;; ─── Simple statement → AST-type checks ─────────────────────────────────

(it-sequential "php-parser-stmt-ast-type if"
  (destructuring-bind (src pred) (list "<?php if ($x) { echo 1; }" #'cl-cc/ast:ast-if-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
(it-sequential "php-parser-stmt-ast-type while"
  (destructuring-bind (src pred) (list "<?php while ($x) { echo 1; }" #'cl-cc/ast:ast-block-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
;;; ─── :if handler → ast-if ────────────────────────────────────────────────

(it-sequential "php-parser-if-else-branch-is-ast-progn"
  (let ((ast (%php-first "<?php if ($x) { echo 1; } else { echo 2; }")))
    (expect (ast-if-p ast) :to-be-truthy)
    (expect (typep (cl-cc/ast:ast-if-else ast) 'cl-cc/ast:ast-progn) :to-be-truthy)))
(it-sequential "php-parser-if-no-else-branch-is-nil-quote"
  (let ((ast (%php-first "<?php if ($x) { echo 1; }")))
    (expect (ast-if-p ast) :to-be-truthy)
    (expect (typep (cl-cc/ast:ast-if-else ast) 'cl-cc/ast:ast-quote) :to-be-truthy)))
;;; ─── :for handler → ast-progn wrapping while ─────────────────────────────

(it-sequential "php-parser-for-produces-ast-progn"
  (let ((ast (%php-first "<?php for ($i = 0; $i < 10; $i++) { echo $i; }")))
    (expect (typep ast 'cl-cc/ast:ast-progn) :to-be-truthy)
    ;; $i = 0 introduces a new variable, so php-finish-let-bindings nests the
    ;; while-loop inside that let — one progn form (the let), not two siblings.
    (expect (= 1 (length (cl-cc/ast:ast-progn-forms ast))) :to-be-truthy)
    (expect (typep (first (cl-cc/ast:ast-progn-forms ast)) 'cl-cc/ast:ast-let) :to-be-truthy)))
;;; ─── Expression statement (dispatch fallthrough) ─────────────────────────

(it-sequential "php-parser-expression-statement-assign"
  (let ((ast (%php-first "<?php $x = 42;")))
    (expect (or (typep ast 'cl-cc/ast:ast-setq)
                      (typep ast 'cl-cc/ast:ast-let)
                      (typep ast 'cl-cc/ast:ast-call)) :to-be-truthy))))
