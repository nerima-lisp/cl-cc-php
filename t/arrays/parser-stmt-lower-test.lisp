(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential "php-parser-stmt-ast-type foreach"
  (destructuring-bind (src pred) (list "<?php foreach ($items as $item) { echo $item; }" #'cl-cc/ast:ast-let-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  (it-sequential "php-parser-stmt-ast-type foreach-kv"
  (destructuring-bind (src pred) (list "<?php foreach ($arr as $k => $v) { echo $v; }" #'cl-cc/ast:ast-let-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  (it-sequential "php-parser-foreach-ordered-iteration"
  (let ((ast (%php-first "<?php foreach ($arr as $k => $v) { echo $v; }")))
    (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
    (let ((bindings (cl-cc/ast:ast-let-bindings ast)))
      (expect (= 2 (length bindings)) :to-be-truthy)))))
