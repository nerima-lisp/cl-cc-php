(in-package :cl-cc/php/syntax/test)

(describe "PHP syntax parser tests"
  (it-sequential "php-parser-variable-names-preserve-case"
  (let* ((asts (cl-cc/php:parse-php-source "<?php $foo = 1; $FOO = 2; $Foo = 3;"))
         (names nil))
    ;; Walk the nested let chain collecting each variable name
    (labels ((collect (nodes)
               (dolist (node nodes)
                 (when (cl-cc/ast:ast-let-p node)
                   (push (symbol-name (car (first (cl-cc/ast:ast-let-bindings node)))) names)
                   (collect (cl-cc/ast:ast-let-body node))))))
      (collect asts))
    (setf names (nreverse names))
    (expect names :to-equal '("foo" "FOO" "Foo"))
    (expect (= 3 (length (remove-duplicates names :test #'string=))) :to-be-truthy)))
  ;;; ─── Multiple top-level statements ───────────────────────────────────────

(it-sequential "php-parser-multi-statement-source"
  (let ((asts (cl-cc/php:parse-php-source "<?php echo 1; echo 2; echo 3;")))
    (expect (= 3 (length asts)) :to-be-truthy)
    (expect (every (lambda (a)
                          (and (cl-cc/ast:ast-call-p a)
                               (string= "%PHP-OUTPUT-WRITE" (%php-call-name a))))
                        asts) :to-be-truthy)))
(it-sequential "php-parser-variable-case-sensitive"
  (let ((ast (%php-first "<?php $foo = $FOO;")))
    (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
    (let* ((bindings (cl-cc/ast:ast-let-bindings ast))
           (lhs (car (first bindings)))
           (rhs (cdr (first bindings))))
      (expect (cl-cc/ast:ast-var-p rhs) :to-be-truthy)
      (expect (string= (symbol-name lhs) (symbol-name (cl-cc/ast:ast-var-name rhs))) :to-be-falsy)))))
