;;;; runtime-builtins-array-compare.lisp — PHP array set operations.
;;;;
;;;; array_diff / array_intersect and their _key and _assoc variants, plus
;;;; array_merge_recursive: everything that answers "which elements of this
;;;; array also appear in those arrays?" using PHP's built-in comparison rules.
;;;; The callback-driven variants (array_udiff, array_uintersect) live in
;;;; runtime-builtins-array-callable.lisp instead, because what they exercise is
;;;; the callable resolver, not the comparison rule.

(in-package :cl-cc/php)

;;; ─── By value ───────────────────────────────────────────────────────────────

(defun %php-array-diff (array &rest arrays)
  "PHP array_diff: elements in first not in others (by value)."
  (let* ((others (loop for a in arrays append (mapcar #'cdr (%php-array-pairs a))))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (unless (member (cdr pair) others :test #'%php-array-value-string=)
        (%php-array-set result (car pair) (cdr pair))))
    result))
(defun %php-array-intersect (array &rest arrays)
  "PHP array_intersect: elements in first also in all others."
  (let* ((others (loop for a in arrays collect (mapcar #'cdr (%php-array-pairs a))))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (when (every (lambda (other)
                     (member (cdr pair) other :test #'%php-array-value-string=))
                   others)
        (%php-array-set result (car pair) (cdr pair))))
    result))
;;; ─── By key ─────────────────────────────────────────────────────────────────

(defun %php-array-diff-key (array &rest arrays)
  "PHP array_diff_key: keys in ARRAY not present in any of ARRAYS."
  (let* ((other-keys (loop for a in arrays
                           append (mapcar #'car (%php-array-pairs a))))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (unless (member (car pair) other-keys :test #'equal)
        (%php-array-set result (car pair) (cdr pair))))
    result))
(defun %php-array-intersect-key (array &rest arrays)
  "PHP array_intersect_key: keys in ARRAY present in all of ARRAYS."
  (let* ((other-key-sets (loop for a in arrays
                               collect (mapcar #'car (%php-array-pairs a))))
         (result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (when (every (lambda (ks) (member (car pair) ks :test #'equal)) other-key-sets)
        (%php-array-set result (car pair) (cdr pair))))
    result))
;;; ─── By key and value ───────────────────────────────────────────────────────

(defun %php-array-diff-assoc (array &rest arrays)
  "PHP array_diff_assoc: key+value pairs in ARRAY not in others."
  (let ((result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (unless (some (lambda (a)
                      (%php-array-assoc-pair-match-p a (car pair) (cdr pair)))
                    arrays)
        (%php-array-set result (car pair) (cdr pair))))
    result))
(defun %php-array-intersect-assoc (array &rest arrays)
  "PHP array_intersect_assoc: key+value pairs in ARRAY also in all others."
  (let ((result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (when (every (lambda (a)
                     (%php-array-assoc-pair-match-p a (car pair) (cdr pair)))
                   arrays)
        (%php-array-set result (car pair) (cdr pair))))
    result))
;;; ─── Recursive merge ────────────────────────────────────────────────────────

(defun %php-array-merge-recursive (&rest arrays)
  "PHP array_merge_recursive: merge arrays, combining duplicate keys recursively."
  (let ((result (%php-make-array)))
    (dolist (array arrays)
      (when (hash-table-p array)
        (dolist (pair (%php-array-pairs array))
          (let ((key (car pair)) (val (cdr pair)))
            (cond
              ;; Integer keys are ALWAYS appended (renumbered), never merged by
              ;; key — this is what array_merge (and the recursive descent into a
              ;; list) does.  Previously the key-0 collision of two lists merged
              ;; by key and wrapped, so [[1]]+[[2]] gave [[1,2]] not [1,2].
              ((integerp key)
               (%php-array-set result (%php-array-next-auto-index result) val))
              (t
               (let ((existing (%php-array-ref result key)))
                 (if (%php-null-p existing)
                     (%php-array-set result key val)
                     ;; String-key collision: combine both sides as arrays and
                     ;; merge recursively (a scalar is first wrapped in [x]).
                     (let ((ex (if (hash-table-p existing)
                                   existing
                                   (%php-list-to-array (list existing))))
                           (nw (if (hash-table-p val) val (%php-list-to-array (list val)))))
                       (%php-array-set result key (%php-array-merge-recursive ex nw)))))))))))
    result))
