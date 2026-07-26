;;;; runtime-builtins-array.lisp — PHP array builtins: element and sequence access.
;;;;
;;;; The plain, callback-free operations on a PHP array seen as an ordered
;;;; key/value sequence: copy, merge, push/pop/shift/unshift, membership,
;;;; slicing, reversal, and the first/last key and value accessors.
;;;;
;;;; The rest of the array surface lives next to this file, split by what the
;;;; operation actually does rather than by which PHP function name it carries:
;;;;   runtime-builtins-array-callable.lisp — anything driven by a user callback
;;;;   runtime-builtins-array-compare.lisp  — diff/intersect set operations
;;;;   runtime-builtins-array-reshape.lisp  — operations that build a new shape
;;;;   runtime-builtins-array-sort.lisp     — the sort family

(in-package :cl-cc/php)

(defun %php-copy-array (array)
  "Return a shallow copy of PHP ARRAY preserving insertion order."
  (let ((copy (%php-array)))
    (dolist (pair (%php-array-pairs array) copy)
      (%php-array-set copy (car pair) (cdr pair)))))
(defun %php-array-value-string= (a b)
  "Compare array values using PHP's string representation rule."
  (string= (%php-stringify a) (%php-stringify b)))
(defun %php-array-assoc-pair-match-p (array key value)
  "Return true when ARRAY contains KEY with a PHP array-comparable VALUE."
  (and (%php-array-key-exists array key)
       (%php-array-value-string= (%php-array-ref array key) value)))
(defun %php-array-merge (&rest arrays)
  "Merge PHP ARRAYS into a new array."
  ;; String keys are overwritten; integer keys are appended and reindexed.
  ;; (%php-count (%php-array-merge (%php-list-to-array '(1)) (%php-list-to-array '(2)))) => 2
  (let ((result (%php-array)))
    (dolist (array arrays result)
      (when (hash-table-p array)
        (dolist (pair (%php-array-pairs array))
          (if (integerp (car pair))
              (%php-array-set result (%php-array-next-auto-index result) (cdr pair))
              (%php-array-set result (car pair) (cdr pair))))))))
(defun %php-array-keys (array &optional (filter-value nil filter-supplied-p) strict)
  "Return ARRAY keys as a PHP array, optionally filtered by value."
  ;; (%php-array-values-list (%php-array-keys (%php-array (list t "a" 1)))) => ("a")
  (let ((result (%php-array)))
    (when (hash-table-p array)
      (dolist (pair (%php-array-pairs array) result)
        (when (or (not filter-supplied-p)
                  (if (%php-truthy strict)
                      (%php-eq-strict filter-value (cdr pair))
                      (%php-eq-loose filter-value (cdr pair))))
          (%php-array-set result (%php-array-next-auto-index result) (car pair)))))))
(defun %php-array-values (array)
  "Return ARRAY values as a reindexed PHP array."
  (%php-list-to-array (%php-array-values-list array)))
(defun %php-array-push (array &rest values)
  "Append VALUES to ARRAY and return the new count."
  ;; (let ((a (%php-array))) (%php-array-push a "x")) => 1
  (check-type array hash-table)
  (dolist (value values (%php-count array))
    (%php-array-set array (%php-array-next-auto-index array) value)))
(defun %php-array-append-target (&rest _)
  "Stub for the $a[] append marker reached in read context, which is a PHP fatal
error (\"Cannot use [] for reading\"). Valid code consumes the marker at assignment
time, so this only fires on misuse."
  (declare (ignore _))
  (%php-fatal-error "PHP fatal error: Cannot use [] for reading"))
(defun %php-array-pop (array)
  "Remove and return ARRAY's last value, or PHP null for an empty array."
  (check-type array hash-table)
  (let ((keys (%php-array-ordered-keys array)))
    (if keys
        (let* ((key (car (last keys)))
               (value (gethash key array)))
          (%php-array-unset array key)
          value)
        +php-null+)))
(defun %php-array-shift (array)
  "Remove and return ARRAY's first value, or PHP null for an empty array."
  (check-type array hash-table)
  (let ((keys (%php-array-ordered-keys array)))
    (if keys
        (let* ((key (first keys))
               (value (gethash key array)))
          (%php-array-unset array key)
          value)
        +php-null+)))
(defun %php-array-unshift (array &rest values)
  "Prepend VALUES to ARRAY and reindex numeric keys."
  ;; (let ((a (%php-list-to-array '(2)))) (%php-array-unshift a 1)) => 2
  (check-type array hash-table)
  (let ((all-values (append values (%php-array-values-list array))))
    (clrhash array)
    (setf (gethash +php-array-order-key+ array) nil
          (gethash +php-array-next-index-key+ array) 0)
    (dolist (value all-values (%php-count array))
      (%php-array-set array (%php-array-next-auto-index array) value))))
(defun %php-in-array (needle haystack &optional strict)
  "Return true when NEEDLE appears in HAYSTACK."
  ;; (%php-in-array 2 (%php-list-to-array '(1 2 3))) => T
  (and (hash-table-p haystack)
       (some (lambda (value)
               (if (%php-truthy strict)
                   (%php-eq-strict needle value)
                   (%php-eq-loose needle value)))
             (%php-array-values-list haystack))))
(defun %php-array-search (needle haystack &optional strict)
  "Return NEEDLE's key in HAYSTACK, or NIL when absent."
  (when (hash-table-p haystack)
    (loop for pair in (%php-array-pairs haystack)
          when (if (%php-truthy strict)
                   (%php-eq-strict needle (cdr pair))
                   (%php-eq-loose needle (cdr pair)))
            return (car pair))))
;;; ─── Strict (===) membership ────────────────────────────────────────────────

(defun %php-in-array-strict (needle haystack)
  "PHP in_array with strict=true: uses === comparison."
  (when (hash-table-p haystack)
    (some (lambda (pair) (equal (cdr pair) needle)) (%php-array-pairs haystack))))
(defun %php-array-search-strict (needle haystack)
  "PHP array_search with strict=true."
  (when (hash-table-p haystack)
    (let ((pair (find-if (lambda (p) (equal (cdr p) needle)) (%php-array-pairs haystack))))
      (if pair (car pair) nil))))
;;; ─── Order-preserving derivation ────────────────────────────────────────────

(defun %php-array-copy-with-key-policy (result key value preserve-keys)
  "Copy VALUE into RESULT using PHP's numeric-key reindexing policy."
  (%php-array-set result
                  (if (or (%php-truthy preserve-keys) (not (integerp key)))
                      key
                      (%php-array-next-auto-index result))
                  value))
(defun %php-array-reverse (array &optional preserve-keys)
  "Return ARRAY values in reverse order."
  ;; (%php-array-values-list (%php-array-reverse (%php-list-to-array '(1 2)))) => (2 1)
  (let ((result (%php-array)))
    (dolist (pair (reverse (%php-array-pairs array)) result)
      (%php-array-copy-with-key-policy result (car pair) (cdr pair) preserve-keys))))
(defun %php-array-slice (array offset &optional length preserve-keys)
  "Return a slice of ARRAY as a PHP array."
  (let* ((pairs (%php-array-pairs array))
         (size (length pairs))
         (start (if (minusp offset) (max 0 (+ size offset)) (min offset size)))
         (end (cond ((or (null length) (%php-null-p length)) size)
                    ((minusp length) (max start (+ size length)))
                    (t (min size (+ start length)))))
         (slice (subseq pairs start end))
         (result (%php-array)))
    (dolist (pair slice result)
      (%php-array-copy-with-key-policy result (car pair) (cdr pair) preserve-keys))))
(defun %php-array-unique (array)
  "Return ARRAY with duplicate values removed, preserving first keys."
  (let ((result (%php-array))
        (seen nil))
    (dolist (pair (%php-array-pairs array) result)
      (unless (some (lambda (value) (%php-array-value-string= value (cdr pair))) seen)
        (push (cdr pair) seen)
        (%php-array-set result (car pair) (cdr pair))))))
;;; ─── First / last key and value ─────────────────────────────────────────────

(defun %php-array-key-first (array)
  "PHP array_key_first: return the first key of ARRAY."
  (let ((pairs (%php-array-pairs array)))
    (if pairs (car (first pairs)) +php-null+)))
(defun %php-array-key-last (array)
  "PHP array_key_last: return the last key of ARRAY."
  (let ((pairs (%php-array-pairs array)))
    (if pairs (car (car (last pairs))) +php-null+)))
(defun %php-array-first (array)
  "PHP array_first: return the first value of ARRAY."
  (let ((pairs (%php-array-pairs array)))
    (if pairs (cdr (first pairs)) +php-null+)))
(defun %php-array-last (array)
  "PHP array_last: return the last value of ARRAY."
  (let ((pairs (%php-array-pairs array)))
    (if pairs (cdr (car (last pairs))) +php-null+)))
;;; ─── Shape predicate ────────────────────────────────────────────────────────

(defun %php-array-is-list (array)
  "PHP array_is_list: check if array has sequential integer keys from 0."
  (when (hash-table-p array)
    (loop for i from 0 for k in (%php-array-ordered-keys array)
          always (eql k i))))
