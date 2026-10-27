(in-package #:cl-cc/php/arrays)

(defvar *php-array-callable-resolver* nil)

;;; -----------------------------------------------------------------------
;;;  foreach by-reference iteration
;;; -----------------------------------------------------------------------

(defun register-php-array-callable-resolver (resolver) (setf *php-array-callable-resolver* resolver))

(defun %php-foreach-by-ref (arr body-fn)
  "Iterate PHP ordered array ARR calling BODY-FN(box key) for each element.
BODY-FN receives a ref box wrapping the current value and the key.
After BODY-FN returns the box is written back to the array (mutations propagate)."
  (let ((fn (and *php-array-callable-resolver* (funcall *php-array-callable-resolver* body-fn))))
    (when (and fn (hash-table-p arr))
      (dolist (key (gethash +php-array-order-key+ arr))
        (let* ((current-val (gethash key arr +php-null+))
               (box (%php-make-ref current-val)))
          (funcall fn box key)
          ;; Write back mutations
          (let ((new-val (%php-deref box)))
            (unless (eq new-val current-val)
              (setf (gethash key arr) new-val)))))))
  +php-null+)
(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :foreach-by-ref '%php-foreach-by-ref))
