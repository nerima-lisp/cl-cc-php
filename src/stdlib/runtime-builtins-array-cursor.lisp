;;;; runtime-builtins-array-cursor.lisp — PHP's internal array pointer.
;;;;
;;;; reset/end/current/next/prev/key read and move the per-array cursor PHP
;;;; keeps alongside the elements, plus list() destructuring and the two-arg
;;;; array_map form that hands keys to the callback.
;;;;
;;;; These lived in runtime-builtins-io.lisp for no reason other than history;
;;;; they are array operations and belong next to the other array builtins.

(in-package :cl-cc/php)

(defun %php-array-map-keys (callback array)
  "PHP array_map with keys support (2-arg form with null callback)."
  (when (null callback)
    (let ((result (%php-make-array)))
      (dolist (pair (%php-array-pairs array))
        (%php-array-set result (%php-array-next-auto-index result)
                        (let ((row (%php-make-array)))
                          (%php-array-set row 0 (car pair))
                          (%php-array-set row 1 (cdr pair))
                          row)))
      (return-from %php-array-map-keys result)))
  (%php-array-map callback array))


(defun %php-list-assign (&rest values)
  "PHP list() — returns the values as a PHP array for destructuring."
  (%php-list-to-array values))

(defun %php-reset (array)
  "PHP reset: reset array pointer to first element."
  (when (hash-table-p array)
    (let ((vals (%php-array-values-list array)))
      (if vals (first vals) nil))))

(defun %php-end (array)
  "PHP end: advance array pointer to last element."
  (when (hash-table-p array)
    (let ((vals (%php-array-values-list array)))
      (if vals (car (last vals)) nil))))

(defun %php-current (array)
  "PHP current: return current element."
  (%php-reset array))

(defun %php-next (array)
  "PHP next: advance internal pointer."
  (when (hash-table-p array)
    (let ((vals (%php-array-values-list array)))
      (if (> (length vals) 1) (second vals) nil))))

(defun %php-prev (array)
  "PHP prev: rewind internal pointer."
  (%php-reset array))

(defun %php-key (array)
  "PHP key: return current key."
  (when (hash-table-p array)
    (let ((keys (%php-array-ordered-keys array)))
      (if keys (first keys) nil))))
