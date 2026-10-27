(in-package :cl-cc/php/match/test)

(describe "PHP match expression tests"
  (it-sequential "php-parser-match-strict-comparison"
  (let ((ast (%php-first "<?php $x = match($v) { 1 => 'one', 2 => 'two' };")))
    (let ((val (cdr (first (cl-cc/ast:ast-let-bindings ast)))))
      (expect (cl-cc/ast:ast-let-p val) :to-be-truthy)
      (let ((if-chain (first (cl-cc/ast:ast-let-body val))))
        (expect (cl-cc/ast:ast-if-p if-chain) :to-be-truthy)
        (let ((cond (cl-cc/ast:ast-if-cond if-chain)))
          (expect (cl-cc/ast:ast-call-p cond) :to-be-truthy)
          (expect (string= "EQUAL" (%php-call-name cond)) :to-be-falsy))))))
  (it-sequential "php-parser-match-expression"
  (let ((value (%php-first-binding-value
                "<?php $result = match($x) { 1 => 'one', 2 => 'two', default => 'other' };")))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (cl-cc/ast:ast-if-p (first (cl-cc/ast:ast-let-body value))) :to-be-truthy)
    (expect (string= "MATCH" (or (%php-call-name value) "")) :to-be-falsy))))
