(in-package :cl-cc/php/expressions/test)

(describe "PHP expression parser tests"
  (it-sequential "php-parser-isset-syntax-lowering"
  (let ((ast (%php-first "<?php $result = isset($x);")))
    (let ((call (cdr (first (cl-cc/ast:ast-let-bindings ast)))))
      (expect (cl-cc/ast:ast-call-p call) :to-be-truthy)
      (expect (search "ISSET" (%php-call-name call)) :to-be-truthy))))
  (it-sequential "php-parser-empty-variable-syntax-lowering"
  (let ((value (%php-first-binding-value "<?php $result = empty($x);")))
    (expect (cl-cc/ast:ast-quote-p value) :to-be-truthy)
    (expect (cl-cc/ast:ast-quote-value value) :to-be t))
  (let* ((let-x (%php-first "<?php $x = 0; $result = empty($x);"))
         (let-result (first (cl-cc/ast:ast-let-body let-x)))
         (value (cdr (first (cl-cc/ast:ast-let-bindings let-result)))))
    (expect (cl-cc/ast:ast-call-p value) :to-be-truthy)
    (expect (search "EMPTY" (%php-call-name value)) :to-be-truthy)))
  (it-sequential "php-parser-null-coalesce-expression"
  (let ((value (%php-first-binding-value "<?php $result = $a ?? $b;")))
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (expect (cl-cc/ast:ast-if-p (first (cl-cc/ast:ast-let-body value))) :to-be-truthy)))
  (it-sequential "php-parser-ternary-expression"
  (let ((value (%php-first-binding-value "<?php $result = $cond ? $yes : $no;")))
    (expect (cl-cc/ast:ast-if-p value) :to-be-truthy))))
