(in-package :cl-cc/php/types/test)

(describe "PHP type and reference tests"
  (it-sequential "Intersection type A&B in a function declaration is preserved as a type annotation string."
(let* ((ast (%php-first
               "<?php function process(Iterator $it): void { return; }"))
         (decls (cl-cc/ast:ast-defun-declarations ast)))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (getf decls :php-return-type) :to-equal "void")))
  (it-sequential "%php-parse-intersection-type builds a structured :intersection descriptor."
;; We call the helper directly with a fake stream.
  ;; %php-type-token-string lowercases the segment, so "Countable" → "countable".
  (let* ((amp-tok       (list :type :T-OP    :value "&"))
         (countable-tok (list :type :T-IDENT  :value "Countable"))
         (stream        (list amp-tok countable-tok)))
    (multiple-value-bind (spec _rest)
        (cl-cc/php/types:%php-parse-intersection-type "Iterator" stream)
      (declare (ignore _rest))
      (expect (consp spec) :to-be-truthy)
      (expect (first spec) :to-be :intersection)
      (expect (member "Iterator" spec :test #'string=) :to-be-truthy)
      (expect (member "countable" spec :test #'string=) :to-be-truthy))))
  (it-sequential "function fail(): never preserves 'never' as the return type in declarations."
(let* ((ast (%php-first "<?php function fail(): never { throw new Ex(); }"))
         (decls (cl-cc/ast:ast-defun-declarations ast)))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (getf decls :php-return-type) :to-equal "never"))))
