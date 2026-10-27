(in-package :cl-cc/php/backend/test)

(describe "PHP backend registration tests"
  (it-sequential "php-parser-registers-bootstrap-backend"
  (let ((parser (cl-cc/bootstrap:find-backend-parser :php))
        (source "<?php echo 1;"))
    (expect parser :to-be-truthy)
    (multiple-value-bind (forms metadata)
        (funcall parser source)
      (expect (= 1 (length forms)) :to-be-truthy)
      (expect (cl-cc/ast:ast-call-p (first forms)) :to-be-truthy)
      (expect metadata :to-be-null)))))
