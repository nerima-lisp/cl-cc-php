;;;; parser-class-e2e-test.lisp — class parsing and enum runtime helper tests.

(in-package :cl-cc-php/test)

(describe "PHP class parser and enum helper tests"


  (it-sequential "php-runtime-enum-helpers"
  (let* ((class (make-hash-table :test #'eq))
         (draft (cl-cc/php:%php-enum-make-case 'status 'draft 0))
         (published (cl-cc/php:%php-enum-make-case 'status 'published 1)))
    (setf (gethash :__class-slots__ class) '(draft published)
          (gethash 'draft class) draft
          (gethash 'published class) published)
    ;; %php-enum-case-list is the internal CL list; %php-enum-cases (ENUM::cases())
    ;; now returns a PHP array (hash-table) so count()/foreach work.
    (expect (cl-cc/php:%php-enum-case-list class) :to-equal (list draft published))
    (expect (hash-table-p (cl-cc/php:%php-enum-cases class)) :to-be-truthy)
    (expect (= 2 (cl-cc/php:%php-count (cl-cc/php:%php-enum-cases class))) :to-be-truthy)
    (expect (cl-cc/php:%php-enum-from class 1) :to-be published)
    (expect (cl-cc/php:%php-enum-try-from class 99) :to-equal cl-cc/php:+php-null+)
    (expect (= 1 (cl-cc/php:%php-enum-case-value published)) :to-be-truthy)))


(it-sequential
    "php-parse-enum-static-builtins"
    (expect
      (= 5
         (length
          (cl-cc/php:parse-php-source
           "<?php enum Status: int { case Draft = 0; case Published = 1; } $a = Status::Published; $b = Status::from(1); $c = Status::tryFrom(99); $d = Status::cases();")))
      :to-be-truthy))


  )
