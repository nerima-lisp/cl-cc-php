(in-package :cl-cc/php/stdlib/test)

(describe "PHP standard library tests"
  (it-sequential "php-parser-count-builtin-lowering"
  (let ((ast (%php-first "<?php $n = count($arr);")))
    (let ((call (cdr (first (cl-cc/ast:ast-let-bindings ast)))))
      (expect (cl-cc/ast:ast-call-p call) :to-be-truthy)
      (expect (%php-call-name call) :to-equal "%PHP-COUNT"))))
  (it-sequential "php-parser-absolute-count-builtin-lowering"
  (let ((ast (%php-first "<?php namespace App\\Lib; $n = \\count($arr);")))
    (let ((call (cdr (first (cl-cc/ast:ast-let-bindings ast)))))
      (expect (cl-cc/ast:ast-call-p call) :to-be-truthy)
      (expect (%php-call-name call) :to-equal "%PHP-COUNT"))))
  (it-sequential "php-parser-namespaced-count-call-does-not-force-global-builtin"
  (let* ((asts (cl-cc/php:parse-php-source
                "<?php namespace App\\Lib; function count($xs) { return 99; } $n = count($arr);"))
         (call (cdr (first (cl-cc/ast:ast-let-bindings (second asts))))))
    (expect (cl-cc/ast:ast-call-p call) :to-be-truthy)
    (expect (%php-call-name call) :to-equal "COUNT"))))
