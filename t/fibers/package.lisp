(defpackage :cl-cc/php/fibers/test
  (:use :cl)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-weave
                #:expect #:gen-string #:it-fuzz #:it-property
                #:it-sequential #:it-sequential-each #:signals)
  (:import-from :cl-cc/php/fibers
                #:%php-fiber-get-return #:%php-fiber-make #:%php-fiber-resume #:%php-fiber-running-p
                #:%php-fiber-start #:%php-fiber-started-p #:%php-fiber-suspend #:%php-fiber-suspended-p
                #:%php-fiber-terminated-p)
  (:import-from :cl-cc/php/types
                #:%php-null-p)
)

