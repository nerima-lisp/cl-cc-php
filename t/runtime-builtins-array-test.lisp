;;;; runtime-builtins-array-test.lisp — src/runtime-builtins-array*.lisp — the array builtin family.

(in-package :cl-cc-php/test)

(describe
  "PHP array_* builtins"
  (it-sequential
    "array copy is a shallow, independent duplicate"
    (let* ((a (cl-cc/php::%php-list-to-array '(1 2 3)))
           (b (cl-cc/php::%php-copy-array a)))
      (cl-cc/php::%php-array-push b 4)
      (expect (cl-cc/php::%php-count a) :to-be 3)
      (expect (cl-cc/php::%php-count b) :to-be 4)
      (expect (cl-cc/php::%php-array-values-list b) :to-equal '(1 2 3 4))))
  (it-sequential
    "array_merge appends integer keys and overwrites string keys"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-merge
          (cl-cc/php::%php-list-to-array '(1 2))
          (cl-cc/php::%php-list-to-array '(3 4))))
      :to-equal
      '(1 2 3 4))
    (let ((r
          (cl-cc/php::%php-array-merge
            (cl-cc/php::%php-array (list t "a" 1))
            (cl-cc/php::%php-array (list t "a" 2)))))
      (expect (cl-cc/php::%php-array-ref r "a") :to-be 2)
      (expect (cl-cc/php::%php-count r) :to-be 1))
    (expect
      (cl-cc/php::%php-count
        (cl-cc/php::%php-array-merge
          (cl-cc/php::%php-list-to-array '(1))
          cl-cc/php::+php-null+))
      :to-be
      1))
  (it-sequential
    "array_keys returns all keys, or keys filtered by value"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-keys (cl-cc/php::%php-list-to-array '(10 20 30))))
      :to-equal
      '(0 1 2))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-keys (cl-cc/php::%php-list-to-array '(1 2 1)) 1))
      :to-equal
      '(0 2))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-keys (cl-cc/php::%php-list-to-array '(1 "1" 1)) 1 t))
      :to-equal
      '(0 2)))
  (it-sequential
    "array_values reindexes to sequential integer keys"
    (let ((a (cl-cc/php::%php-array (list t "x" 1) (list t "y" 2))))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-values a))
        :to-equal
        '(1 2))
      (expect
        (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-array-values a))
        :to-equal
        '(0 1))))
  (it-sequential
    "array_push / array_pop / array_shift / array_unshift mutate in place"
    (let ((a (cl-cc/php::%php-list-to-array '(1 2))))
      (expect (cl-cc/php::%php-array-push a 3 4) :to-be 4)
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(1 2 3 4)))
    (let ((a (cl-cc/php::%php-list-to-array '(1 2 3))))
      (expect (cl-cc/php::%php-array-pop a) :to-be 3)
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(1 2)))
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-pop (cl-cc/php::%php-make-array)))
      :to-be-truthy)
    (let ((a (cl-cc/php::%php-list-to-array '(1 2 3))))
      (expect (cl-cc/php::%php-array-shift a) :to-be 1)
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(2 3)))
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-shift (cl-cc/php::%php-make-array)))
      :to-be-truthy)
    (let ((a (cl-cc/php::%php-list-to-array '(3 4))))
      (expect (cl-cc/php::%php-array-unshift a 1 2) :to-be 4)
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(1 2 3 4))))
  (it-sequential
    "in_array and array_search honor loose vs strict comparison"
    (expect
      (cl-cc/php::%php-in-array 2 (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-in-array 9 (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-in-array "2" (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-in-array "2" (cl-cc/php::%php-list-to-array '(1 2 3)) t)
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-array-search 20 (cl-cc/php::%php-list-to-array '(10 20 30)))
      :to-be
      1)
    (expect
      (cl-cc/php::%php-array-search 99 (cl-cc/php::%php-list-to-array '(10 20 30)))
      :to-be
      nil))
  (it-sequential
    "array_reverse reverses values, reindexing unless keys preserved"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-reverse (cl-cc/php::%php-list-to-array '(1 2 3))))
      :to-equal
      '(3 2 1))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-reverse (cl-cc/php::%php-list-to-array '(1 2 3))))
      :to-equal
      '(0 1 2))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-reverse (cl-cc/php::%php-list-to-array '(1 2 3)) t))
      :to-equal
      '(2 1 0)))
  (it-sequential
    "array_slice handles positive/negative offset, length, and preserve-keys"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-slice (cl-cc/php::%php-list-to-array '(1 2 3 4 5)) 1 2))
      :to-equal
      '(2 3))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-slice (cl-cc/php::%php-list-to-array '(1 2 3 4 5)) -2))
      :to-equal
      '(4 5))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-slice (cl-cc/php::%php-list-to-array '(1 2 3 4 5)) 1 -1))
      :to-equal
      '(2 3 4))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-slice (cl-cc/php::%php-list-to-array '(1 2 3)) 1 nil t))
      :to-equal
      '(1 2))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-slice (cl-cc/php::%php-list-to-array '(1 2 3)) 1))
      :to-equal
      '(0 1)))
  (it-sequential
    "array_unique drops later duplicates, keeping the first key"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-unique (cl-cc/php::%php-list-to-array '(1 2 2 3 3 3))))
      :to-equal
      '(1 2 3))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-unique (cl-cc/php::%php-list-to-array '(1 1 2))))
      :to-equal
      '(0 2)))
  (it-sequential
    "array_map over one array applies the callback and preserves keys"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-map
          (lambda (x)
            (* x x))
          (cl-cc/php::%php-list-to-array '(1 2 3))))
      :to-equal
      '(1 4 9))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-map
          (lambda (x)
            x)
          (cl-cc/php::%php-array (list t "a" 1) (list t "b" 2))))
      :to-equal
      '("a" "b"))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-map
          cl-cc/php::+php-null+
          (cl-cc/php::%php-list-to-array '(1 2))))
      :to-equal
      '(1 2)))
  (it-sequential
    "array_map over multiple arrays zips by position"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-map
          (lambda (a b)
            (+ a b))
          (cl-cc/php::%php-list-to-array '(1 2 3))
          (cl-cc/php::%php-list-to-array '(10 20 30))))
      :to-equal
      '(11 22 33))
    (let ((r
          (cl-cc/php::%php-array-map
            cl-cc/php::+php-null+
            (cl-cc/php::%php-list-to-array '(1 2))
            (cl-cc/php::%php-list-to-array '(3 4)))))
      (expect (cl-cc/php::%php-count r) :to-be 2)
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref r 0))
        :to-equal
        '(1 3))))
  (it-sequential
    "array_filter respects callback, no-callback truthiness, and mode flags"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-filter
          (cl-cc/php::%php-list-to-array '(1 2 3 4))
          (lambda (x)
            (evenp x))))
      :to-equal
      '(2 4))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-filter (cl-cc/php::%php-list-to-array '(0 1 2 0 3))))
      :to-equal
      '(1 2 3))
    (expect
      (cl-cc/php::%php-array-ordered-keys
        (cl-cc/php::%php-array-filter
          (cl-cc/php::%php-array (list t "a" 1) (list t "bb" 2))
          (lambda (k)
            (= (length k) 1))
          2))
      :to-equal
      '("a"))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-filter
          (cl-cc/php::%php-list-to-array '(10 20 30))
          (lambda (v k)
            (and (> v 10) (> k 0)))
          1))
      :to-equal
      '(20 30)))
  (it-sequential
    "array_reduce folds with an initial accumulator, defaulting to null"
    (expect
      (cl-cc/php::%php-array-reduce
        (cl-cc/php::%php-list-to-array '(1 2 3 4))
        (lambda (acc x)
          (+ acc x))
        0)
      :to-be
      10)
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-reduce
          (cl-cc/php::%php-make-array)
          (lambda (a b)
            (+ a b))))
      :to-be-truthy))
  (it-sequential
    "range produces ascending, descending, stepped, and character sequences"
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-range 1 5))
      :to-equal
      '(1 2 3 4 5))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-range 5 1))
      :to-equal
      '(5 4 3 2 1))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-range 0 10 5))
      :to-equal
      '(0 5 10))
    (expect
      (cl-cc/php::%php-array-values-list (cl-cc/php::%php-range "a" "c"))
      :to-equal
      '("a" "b" "c")))
  (it-sequential
    "array_walk visits every value/key pair"
    (let ((sum 0)
          (a (cl-cc/php::%php-list-to-array '(1 2 3))))
      (cl-cc/php::%php-array-walk
        a
        (lambda (v k)
          (declare (ignore k))
          (incf sum v)))
      (expect sum :to-be 6)))
  (it-sequential
    "array_chunk splits into fixed-size groups with a smaller final chunk"
    (let ((r (cl-cc/php::%php-array-chunk (cl-cc/php::%php-list-to-array '(1 2 3 4 5)) 2)))
      (expect (cl-cc/php::%php-count r) :to-be 3)
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref r 0))
        :to-equal
        '(1 2))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref r 2))
        :to-equal
        '(5))))
  (it-sequential
    "array_pad extends right, left, or leaves longer arrays alone"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-pad (cl-cc/php::%php-list-to-array '(1 2)) 4 0))
      :to-equal
      '(1 2 0 0))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-pad (cl-cc/php::%php-list-to-array '(1 2)) -4 0))
      :to-equal
      '(0 0 1 2))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-pad (cl-cc/php::%php-list-to-array '(1 2 3)) 2 0))
      :to-equal
      '(1 2 3)))
  (it-sequential
    "array_count_values tallies scalar occurrences"
    (let ((r
          (cl-cc/php::%php-array-count-values
            (cl-cc/php::%php-list-to-array '("a" "b" "a" "c" "b" "a")))))
      (expect (cl-cc/php::%php-array-ref r "a") :to-be 3)
      (expect (cl-cc/php::%php-array-ref r "b") :to-be 2)
      (expect (cl-cc/php::%php-array-ref r "c") :to-be 1)))
  (it-sequential
    "array_sum and array_product operate over numeric values only"
    (expect
      (cl-cc/php::%php-array-sum (cl-cc/php::%php-list-to-array '(1 2 3 4)))
      :to-be
      10)
    (expect
      (cl-cc/php::%php-array-product (cl-cc/php::%php-list-to-array '(1 2 3 4)))
      :to-be
      24)
    (expect
      (cl-cc/php::%php-array-sum
        (cl-cc/php::%php-array (list nil nil 1) (list nil nil "x") (list nil nil 2)))
      :to-be
      3))
  (it-sequential
    "array_diff and array_intersect compare by value"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-diff
          (cl-cc/php::%php-list-to-array '(1 2 3 4))
          (cl-cc/php::%php-list-to-array '(2 4))))
      :to-equal
      '(1 3))
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-intersect
          (cl-cc/php::%php-list-to-array '(1 2 3 4))
          (cl-cc/php::%php-list-to-array '(2 4 6))))
      :to-equal
      '(2 4)))
  (it-sequential
    "array_udiff and array_uintersect compare via a user callback"
    (let ((cmp
          (lambda (a b)
            (- a b))))
      (expect
        (cl-cc/php::%php-array-values-list
          (cl-cc/php::%php-array-udiff
            (cl-cc/php::%php-list-to-array '(1 2 3 4))
            (cl-cc/php::%php-list-to-array '(2 4))
            cmp))
        :to-equal
        '(1 3))
      (expect
        (cl-cc/php::%php-array-values-list
          (cl-cc/php::%php-array-uintersect
            (cl-cc/php::%php-list-to-array '(1 2 3 4))
            (cl-cc/php::%php-list-to-array '(2 4 6))
            cmp))
        :to-equal
        '(2 4))))
  (it-sequential
    "array_column extracts a column, optionally re-indexed"
    (let* ((row1 (cl-cc/php::%php-array (list t "id" 1) (list t "name" "a")))
           (row2 (cl-cc/php::%php-array (list t "id" 2) (list t "name" "b")))
           (input (cl-cc/php::%php-list-to-array (list row1 row2))))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-column input "name"))
        :to-equal
        '("a" "b"))
      (let ((r (cl-cc/php::%php-array-column input "name" "id")))
        (expect (cl-cc/php::%php-array-ref r 1) :to-equal "a")
        (expect (cl-cc/php::%php-array-ref r 2) :to-equal "b"))))
  (it-sequential
    "array_combine pairs keys with values, array_flip swaps them"
    (let ((r
          (cl-cc/php::%php-array-combine
            (cl-cc/php::%php-list-to-array '("a" "b"))
            (cl-cc/php::%php-list-to-array '(1 2)))))
      (expect (cl-cc/php::%php-array-ref r "a") :to-be 1)
      (expect (cl-cc/php::%php-array-ref r "b") :to-be 2))
    (let ((r (cl-cc/php::%php-array-flip (cl-cc/php::%php-list-to-array '("x" "y" "z")))))
      (expect (cl-cc/php::%php-array-ref r "x") :to-be 0)
      (expect (cl-cc/php::%php-array-ref r "z") :to-be 2)))
  (it-sequential
    "array_fill and array_fill_keys build filled arrays"
    (let ((r (cl-cc/php::%php-array-fill 5 3 "x")))
      (expect (cl-cc/php::%php-array-ordered-keys r) :to-equal '(5 6 7))
      (expect (cl-cc/php::%php-array-ref r 5) :to-equal "x"))
    (let ((r
          (cl-cc/php::%php-array-fill-keys (cl-cc/php::%php-list-to-array '("a" "b")) 0)))
      (expect (cl-cc/php::%php-array-ref r "a") :to-be 0)
      (expect (cl-cc/php::%php-array-ref r "b") :to-be 0)))
  (it-sequential
    "array_splice removes a range and can insert a replacement"
    (let* ((a (cl-cc/php::%php-list-to-array '(1 2 3 4 5)))
           (removed (cl-cc/php::%php-array-splice a 1 2)))
      (expect (cl-cc/php::%php-array-values-list removed) :to-equal '(2 3))
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(1 4 5)))
    (let* ((a (cl-cc/php::%php-list-to-array '(1 2 3)))
           (removed
          (cl-cc/php::%php-array-splice a 1 1 (cl-cc/php::%php-list-to-array '(9 8)))))
      (expect (cl-cc/php::%php-array-values-list removed) :to-equal '(2))
      (expect (cl-cc/php::%php-array-values-list a) :to-equal '(1 9 8 3))))
  (it-sequential
    "array_replace overlays later arrays onto the first"
    (let ((r
          (cl-cc/php::%php-array-replace
            (cl-cc/php::%php-array (list t "a" 1) (list t "b" 2))
            (cl-cc/php::%php-array (list t "b" 20) (list t "c" 30)))))
      (expect (cl-cc/php::%php-array-ref r "a") :to-be 1)
      (expect (cl-cc/php::%php-array-ref r "b") :to-be 20)
      (expect (cl-cc/php::%php-array-ref r "c") :to-be 30)))
  (it-sequential
    "array_diff_key and array_intersect_key compare by key"
    (let ((a (cl-cc/php::%php-array (list t "a" 1) (list t "b" 2) (list t "c" 3)))
          (b (cl-cc/php::%php-array (list t "b" 9))))
      (expect
        (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-array-diff-key a b))
        :to-equal
        '("a" "c"))
      (expect
        (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-array-intersect-key a b))
        :to-equal
        '("b"))))
  (it-sequential
    "array_diff_assoc and array_intersect_assoc compare key+value pairs"
    (let ((a (cl-cc/php::%php-array (list t "a" 1) (list t "b" 2)))
          (b (cl-cc/php::%php-array (list t "a" 1) (list t "b" 99))))
      (expect
        (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-array-diff-assoc a b))
        :to-equal
        '("b"))
      (expect
        (cl-cc/php::%php-array-ordered-keys (cl-cc/php::%php-array-intersect-assoc a b))
        :to-equal
        '("a"))))
  (it-sequential
    "array_merge_recursive appends integer keys and combines string-key collisions"
    (expect
      (cl-cc/php::%php-array-values-list
        (cl-cc/php::%php-array-merge-recursive
          (cl-cc/php::%php-list-to-array '(1))
          (cl-cc/php::%php-list-to-array '(2))))
      :to-equal
      '(1 2))
    (let ((r
          (cl-cc/php::%php-array-merge-recursive
            (cl-cc/php::%php-array (list t "k" "x"))
            (cl-cc/php::%php-array (list t "k" "y")))))
      (expect
        (cl-cc/php::%php-array-values-list (cl-cc/php::%php-array-ref r "k"))
        :to-equal
        '("x" "y"))))
  (it-sequential
    "array_key_first/last and array_first/last read the ends, null when empty"
    (let ((a (cl-cc/php::%php-array (list t "a" 10) (list t "b" 20))))
      (expect (cl-cc/php::%php-array-key-first a) :to-equal "a")
      (expect (cl-cc/php::%php-array-key-last a) :to-equal "b")
      (expect (cl-cc/php::%php-array-first a) :to-be 10)
      (expect (cl-cc/php::%php-array-last a) :to-be 20))
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-key-first (cl-cc/php::%php-make-array)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-first (cl-cc/php::%php-make-array)))
      :to-be-truthy))
  (it-sequential
    "array_find/find_key/any/all (PHP 8.4) run the predicate"
    (expect
      (cl-cc/php::%php-array-find
        (cl-cc/php::%php-list-to-array '(1 2 3 4))
        (lambda (x)
          (> x 2)))
      :to-be
      3)
    (expect
      (cl-cc/php::%php-null-p
        (cl-cc/php::%php-array-find
          (cl-cc/php::%php-list-to-array '(1 2))
          (lambda (x)
            (> x 9))))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-array-find-key
        (cl-cc/php::%php-list-to-array '(1 2 3 4))
        (lambda (x)
          (> x 2)))
      :to-be
      2)
    (expect
      (cl-cc/php::%php-array-any
        (cl-cc/php::%php-list-to-array '(1 2 3))
        (lambda (x)
          (> x 2)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-array-any
        (cl-cc/php::%php-list-to-array '(1 2 3))
        (lambda (x)
          (> x 9)))
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-array-all
        (cl-cc/php::%php-list-to-array '(2 4 6))
        (lambda (x)
          (evenp x)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-array-all
        (cl-cc/php::%php-list-to-array '(2 3 6))
        (lambda (x)
          (evenp x)))
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-array-all
        (cl-cc/php::%php-make-array)
        (lambda (x)
          (declare (ignore x))
          nil))
      :to-be-truthy))
  (it-sequential
    "in_array strict and array_search strict use === comparison"
    (expect
      (cl-cc/php::%php-in-array-strict 2 (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-in-array-strict "2" (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-array-search-strict 2 (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be
      1)
    (expect
      (cl-cc/php::%php-array-search-strict 9 (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be
      nil))
  (it-sequential
    "array_is_list is true only for sequential integer keys from zero"
    (expect
      (cl-cc/php::%php-array-is-list (cl-cc/php::%php-list-to-array '(1 2 3)))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-array-is-list (cl-cc/php::%php-array (list t "a" 1)))
      :to-be
      nil)
    (expect
      (cl-cc/php::%php-array-is-list (cl-cc/php::%php-make-array))
      :to-be-truthy)))
