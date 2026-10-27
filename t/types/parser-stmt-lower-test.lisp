(in-package :cl-cc/php/types/test)

(describe "PHP type and reference tests"
  (it-sequential "php-parser-reference-assignment-lowers-to-ref-box"
  (let* ((ast (%php-first "<?php $a=1; $b=&$a; echo $b;"))
         (body (cl-cc/ast:ast-let-body ast))
         (box-set (first body))
         (alias-let (second body))
         (echo (first (cl-cc/ast:ast-let-body alias-let)))
         (concat (first (cl-cc/ast:ast-call-args echo)))
         (deref (first (cl-cc/ast:ast-call-args concat))))
    (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
    (expect (cl-cc/ast:ast-setq-p box-set) :to-be-truthy)
    (expect (%php-call-name (cl-cc/ast:ast-setq-value box-set)) :to-equal "%PHP-MAKE-REF")
    (expect (cl-cc/ast:ast-let-p alias-let) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-p (cdr (first (cl-cc/ast:ast-let-bindings alias-let)))) :to-be-truthy)
    (expect (%php-call-name deref) :to-equal "%PHP-DEREF")))
  (it-sequential "php-parser-settype-lowers-first-arg-by-reference"
  (let ((found-box nil)
        (found-writeback nil))
    (labels ((walk (node)
               (when (cl-cc/ast:ast-call-p node)
                 (when (string= "%PHP-MAKE-REF" (%php-call-name node))
                   (setf found-box t)))
               (when (cl-cc/ast:ast-setq-p node)
                 (when (string= (symbol-name (cl-cc/ast:ast-setq-var node)) "x")
                   (setf found-writeback t)))
               (when (typep node 'cl-cc/ast:ast-node)
                 (dolist (child (cl-cc/ast:ast-children node))
                   (when child
                     (walk child))))))
      (dolist (ast (cl-cc/php:parse-php-source "<?php $x=5; settype($x,'string');"))
        (walk ast)))
    (expect found-box :to-be-truthy)
    (expect found-writeback :to-be-truthy)))
  ;;; ─── Characterization tests for unsupported PHP support gaps ───────────────

(it-sequential "php-parser-null-distinct-from-false"
  (let ((null-ast (%php-first "<?php $x = null;"))
        (false-ast (%php-first "<?php $x = false;")))
    (let ((null-val (cl-cc/ast:ast-quote-value (cdr (first (cl-cc/ast:ast-let-bindings null-ast)))))
          (false-val (cl-cc/ast:ast-quote-value (cdr (first (cl-cc/ast:ast-let-bindings false-ast))))))
      (expect (eql null-val false-val) :to-be-falsy))))
(it-sequential "php-parser-truthiness-rules"
  (let ((ast (%php-first "<?php if ($x) { echo 1; } else { echo 2; }")))
    (expect (cl-cc/ast:ast-if-p ast) :to-be-truthy)
    (let ((cond (cl-cc/ast:ast-if-cond ast)))
      (expect (cl-cc/ast:ast-call-p cond) :to-be-truthy)
      (expect (%php-call-name cond) :to-equal "%PHP-TRUTHY")))))
