(in-package :cl-cc/php/backend/test)

(describe "PHP current closure bridge"
          ""
          (it-sequential
           "publishes the current closure as a callable backend bridge"
           (let ((entry
                  (find "%PHP-CURRENT-CLOSURE"
                        (cl-cc/php/backend:%php-host-bridge-entries)
                        :key
                        (lambda (pair)
                          (symbol-name (car pair)))
                        :test
                        (function string=))))
             (expect entry :to-be-truthy)
             (expect (functionp (cdr entry)) :to-be-truthy))))
