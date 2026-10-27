(in-package :cl-cc/php/arrays/test)

(describe "PHP array tests"
  (it-sequential "array_find() returns the first element satisfying the callback."
(let* ((arr (cl-cc/php:%php-array (list nil nil 3) (list nil nil 7) (list nil nil 4)))
         (result (cl-cc/php:%php-array-find arr (lambda (v) (> v 5)))))
    (expect (= 7 result) :to-be-truthy)))
  (it-sequential "array_find() returns +php-null+ when no element satisfies the callback."
(let* ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2)))
         (result (cl-cc/php:%php-array-find arr (lambda (v) (> v 10)))))
    (expect result :to-equal cl-cc/php:+php-null+)))
  (it-sequential "array_find_key() returns the integer key of the first matching element."
(let* ((arr (cl-cc/php:%php-array (list nil nil 10) (list nil nil 20) (list nil nil 30)))
         (result (cl-cc/php:%php-array-find-key arr (lambda (v) (= v 20)))))
    (expect (= 1 result) :to-be-truthy)))
  (it-sequential "array_find_key() returns +php-null+ when no element matches."
(let* ((arr (cl-cc/php:%php-array (list nil nil 1)))
         (result (cl-cc/php:%php-array-find-key arr (lambda (v) (> v 100)))))
    (expect result :to-equal cl-cc/php:+php-null+)))
  (it-sequential "array_any() returns true when at least one element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2) (list nil nil 50))))
    (expect (cl-cc/php:%php-array-any arr (lambda (v) (> v 10))) :to-be-truthy)))
  (it-sequential "array_any() returns false when no element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 1) (list nil nil 2))))
    (expect (cl-cc/php:%php-array-any arr (lambda (v) (> v 100))) :to-be-falsy)))
  (it-sequential "array_all() returns true when every element satisfies the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 5) (list nil nil 10) (list nil nil 20))))
    (expect (cl-cc/php:%php-array-all arr (lambda (v) (> v 0))) :to-be-truthy)))
  (it-sequential "array_all() returns false when any element fails the callback."
(let ((arr (cl-cc/php:%php-array (list nil nil 5) (list nil nil -1))))
    (expect (cl-cc/php:%php-array-all arr (lambda (v) (> v 0))) :to-be-falsy)))
  (it-sequential "array_all() returns true for an empty array (vacuous truth)."
    (let ((arr (cl-cc/php:%php-array)))
      (expect (cl-cc/php:%php-array-all arr (lambda (v) (declare (ignore v)))) :to-be-truthy)
      (expect (cl-cc/php:%php-array-all (cl-cc/php:%php-array (list nil nil 1))
                                  (lambda (v) (declare (ignore v)) nil)) :to-be-falsy))))
