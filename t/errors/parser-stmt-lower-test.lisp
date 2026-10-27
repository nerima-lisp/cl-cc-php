(in-package :cl-cc/php/errors/test)

(describe "PHP error and exception tests"
  (it-sequential "php-parser-throw-catch-consistency"
  (let ((ast (%php-first "<?php try { throw new Ex(); } catch (Ex $e) { echo 'caught'; }")))
    (expect (cl-cc/ast:ast-unwind-protect-p ast) :to-be-truthy)
    (expect (cl-cc/ast:ast-let-p (cl-cc/ast:ast-unwind-protected ast)) :to-be-truthy))))
