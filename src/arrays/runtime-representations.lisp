(in-package #:cl-cc/php/arrays)

(defconstant +php-array-order-key+ :__php-array-order
  "Reserved hash-table key storing PHP array insertion order.")

(defconstant +php-array-next-index-key+ :__php-array-next-index
  "Reserved hash-table key storing the next PHP auto-increment index.")

(in-package #:cl-cc/php/arrays)

(defun %php-list-to-array (values)
  "Return a PHP ordered array containing VALUES at numeric keys."
  ;; (%php-count (%php-list-to-array '("a" "b"))) => 2
  (let ((array (%php-array)))
    (dolist (value values array)
      (%php-array-set array (%php-array-next-auto-index array) value))))

(defun %php-array-values-list (array)
  "Return ARRAY's values as a Common Lisp list in PHP insertion order."
  ;; (%php-array-values-list (%php-array (list nil nil "a") (list nil nil "b")))
  ;; => ("a" "b")
  (check-type array hash-table)
  (loop for key in (%php-array-ordered-keys array)
        collect (gethash key array)))

(defun %php-array-pairs (array)
  "Return ARRAY's ordered (KEY . VALUE) pairs."
  ;; (%php-array-pairs (%php-array (list t "a" 1))) => (("a" . 1))
  (check-type array hash-table)
  (loop for key in (%php-array-ordered-keys array)
        collect (cons key (gethash key array))))

(defun %php-array-ordered-keys (array)
  "Return ARRAY's user keys in PHP insertion order."
  ;; (%php-array-ordered-keys (%php-array (list nil nil "a"))) => (0)
  (check-type array hash-table)
  (copy-list (gethash +php-array-order-key+ array)))
