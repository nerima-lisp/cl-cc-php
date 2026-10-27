;;;; runtime-builtins-array-reshape.lisp — PHP array builtins that build a new
;;;; shape.
;;;;
;;;; Generation (range, array_fill), regrouping (array_chunk, array_pad,
;;;; array_column, array_combine, array_flip), aggregation (array_sum,
;;;; array_product, array_count_values), and the two in-place restructurings
;;;; (array_splice, shuffle). What they have in common is that the result's
;;;; key/value structure is not the input's — unlike the sequence operations in
;;;; runtime-builtins-array.lisp, which preserve it.

(in-package :cl-cc/php)

;;; ─── Generation ─────────────────────────────────────────────────────────────

(defun %php-range (start end &optional (step 1))
  "Return a PHP array containing values from START to END by STEP."
  ;; (%php-array-values-list (%php-range 1 3)) => (1 2 3)
  (let ((result (%php-array))
        (actual-step (if (or (null step) (zerop step)) 1 (abs step))))
    (if (and (numberp start) (numberp end))
        (if (<= start end)
            (loop for value from start to end by actual-step
                  do (%php-array-set result (%php-array-next-auto-index result) value))
            (loop for value from start downto end by actual-step
                  do (%php-array-set result (%php-array-next-auto-index result) value)))
        (let ((s (char-code (char (%php-stringify start) 0)))
              (e (char-code (char (%php-stringify end) 0))))
          (if (<= s e)
              (loop for code from s to e by actual-step
                    do (%php-array-set result (%php-array-next-auto-index result)
                                       (string (code-char code))))
              (loop for code from s downto e by actual-step
                    do (%php-array-set result (%php-array-next-auto-index result)
                                       (string (code-char code)))))))
    result))
(defun %php-array-fill (start-index num value)
  "PHP array_fill: fill array with VALUE starting at START-INDEX."
  (let ((result (%php-make-array)))
    (dotimes (i num)
      (%php-array-set result (+ start-index i) value))
    result))
(defun %php-array-fill-keys (keys value)
  "PHP array_fill_keys: create array using KEYS with VALUE."
  (let ((result (%php-make-array)))
    (dolist (k (%php-array-values-list keys))
      (%php-array-set result k value))
    result))
;;; ─── Regrouping ─────────────────────────────────────────────────────────────

(defun %php-array-chunk (array size &optional preserve-keys)
  "PHP array_chunk: split ARRAY into chunks of SIZE."
  (let* ((pairs (%php-array-pairs array))
         (result (%php-make-array))
         (chunk nil)
         (chunk-idx 0)
         (key-idx 0))
    (dolist (pair pairs)
      (when (and chunk (= (length chunk) size))
        (let ((c (%php-make-array)))
          (loop for i from 0 for p in (nreverse chunk)
                do (%php-array-set c (if preserve-keys (car p) i) (cdr p)))
          (%php-array-set result chunk-idx c)
          (incf chunk-idx)
          (setf chunk nil key-idx 0)))
      (push pair chunk)
      (incf key-idx))
    (when chunk
      (let ((c (%php-make-array)))
        (loop for i from 0 for p in (nreverse chunk)
              do (%php-array-set c (if preserve-keys (car p) i) (cdr p)))
        (%php-array-set result chunk-idx c)))
    result))
(defun %php-array-pad (array size value)
  "PHP array_pad: pad array to SIZE with VALUE."
  (let* ((pairs (%php-array-pairs array))
         (current-size (length pairs))
         (target (abs size))
         (result (%php-make-array)))
    (if (>= current-size target)
        ;; array_pad returns a copy; integer keys are reindexed, string keys survive.
        (dolist (pair pairs result)
          (%php-array-copy-with-key-policy result (car pair) (cdr pair) nil))
        (let ((pad-count (- target current-size)))
          (if (< size 0)
              (progn
                (dotimes (_ pad-count)
                  (%php-array-set result (%php-array-next-auto-index result) value))
                (dolist (pair pairs)
                  (%php-array-copy-with-key-policy result (car pair) (cdr pair) nil)))
              (progn
                (dolist (pair pairs)
                  (%php-array-copy-with-key-policy result (car pair) (cdr pair) nil))
                (dotimes (_ pad-count)
                  (%php-array-set result (%php-array-next-auto-index result) value))))
          result))))
(defun %php-array-column (input column-key &optional index-key)
  "PHP array_column: extract values from COLUMN-KEY across rows, optionally indexed by INDEX-KEY."
  (let ((result (%php-make-array))
        (all-columns-p (or (null column-key) (%php-null-p column-key)))
        (indexed-p (and index-key (not (%php-null-p index-key)))))
    (dolist (pair (%php-array-pairs input))
      (let ((row (cdr pair)))
        (when (and (hash-table-p row)
                   (or all-columns-p (%php-array-key-present-p row column-key)))
          (let ((value (if all-columns-p row (%php-array-ref row column-key)))
                (has-index-p (and indexed-p (%php-array-key-present-p row index-key))))
            (%php-array-set result
                            (if has-index-p
                                (%php-array-ref row index-key)
                                (%php-array-next-auto-index result))
                            value)))))
    result))
(defun %php-array-combine (keys values)
  "PHP array_combine: create array from KEYS and VALUES arrays."
  (let* ((ks (%php-array-values-list keys))
         (vs (%php-array-values-list values))
         (result (%php-make-array)))
    (loop for k in ks for v in vs
          do (%php-array-set result k v))
    result))
(defun %php-array-flip (array)
  "PHP array_flip: exchange keys and values."
  (let ((result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (let ((value (cdr pair)))
        (when (or (integerp value) (stringp value))
          (%php-array-set result value (car pair)))))
    result))
;;; ─── Aggregation ────────────────────────────────────────────────────────────

(defun %php-array-count-values (array)
  "PHP array_count_values: count occurrences of each value."
  (let ((result (%php-make-array)))
    (dolist (pair (%php-array-pairs array))
      (let ((value (cdr pair)))
        (when (or (integerp value) (stringp value))
          (let* ((v (%php-stringify value))
                 (current (%php-array-ref result v)))
            (%php-array-set result v (if (%php-null-p current) 1 (1+ current)))))))
    result))
(defun %php-array-sum (array)
  "PHP array_sum: sum all numeric values."
  (let ((sum 0))
    (dolist (pair (%php-array-pairs array))
      (let ((v (cdr pair)))
        (when (numberp v) (incf sum v))))
    sum))
(defun %php-array-product (array)
  "PHP array_product: multiply all numeric values."
  (let ((product 1))
    (dolist (pair (%php-array-pairs array))
      (let ((v (cdr pair)))
        (when (numberp v) (setf product (* product v)))))
    product))
;;; ─── In-place restructuring ─────────────────────────────────────────────────

(defun %php-array-splice (array offset &optional length replacement)
  "PHP array_splice: remove LENGTH elements at OFFSET, optionally insert REPLACEMENT."
  (let* ((pairs (%php-array-pairs array))
         (size (length pairs))
         (start (if (minusp offset) (max 0 (+ size offset)) (min offset size)))
         (end (cond ((or (null length) (%php-null-p length)) size)
                    ((minusp length) (max start (+ size length)))
                    (t (min size (+ start length)))))
         (before (subseq pairs 0 start))
         (removed (subseq pairs start end))
         (after (subseq pairs end))
         (inserts (when (and replacement (hash-table-p replacement))
                    (mapcar #'cdr (%php-array-pairs replacement))))
         (new-pairs (append before
                            (mapcar (lambda (v) (cons 0 v)) inserts)
                            after)))
    (clrhash array)
    (setf (gethash +php-array-order-key+ array) nil
          (gethash +php-array-next-index-key+ array) 0)
    (loop for pair in new-pairs
          do (%php-array-set array (%php-array-next-auto-index array) (cdr pair)))
    (%php-list-to-array (mapcar #'cdr removed))))
(defun %php-array-replace (array &rest replacements)
  "PHP array_replace: replace values in ARRAY with values from REPLACEMENTS."
  (let ((result (%php-copy-array array)))
    (dolist (r replacements)
      (when (hash-table-p r)
        (dolist (pair (%php-array-pairs r))
          (%php-array-set result (car pair) (cdr pair)))))
    result))
(defun %php-shuffle (array)
  "PHP shuffle: randomize order of ARRAY elements."
  (let* ((values (%php-array-values-list array))
         (vec (coerce values 'vector))
         (n (length vec)))
    (loop for i from (1- n) downto 1
          do (let* ((j (random (1+ i)))
                    (tmp (aref vec i)))
               (setf (aref vec i) (aref vec j)
                     (aref vec j) tmp)))
    (clrhash array)
    (setf (gethash +php-array-order-key+ array) nil
          (gethash +php-array-next-index-key+ array) 0)
    (loop for v across vec
          do (%php-array-set array (%php-array-next-auto-index array) v))
    t))
