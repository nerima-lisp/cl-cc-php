;;;; runtime-builtins-array-transform-test.lisp — src/runtime-builtins-array-reshape.lisp and
;;;; -compare.lisp — chunking, padding, counting, filling, splicing, and diff/intersect variants.
;;;;
;;;; Split out of runtime-builtins-array-test.lisp, which stayed over the 500-line limit: these
;;;; eleven tests are the ones that derive a new array shape from existing arrays, rather than the
;;;; core CRUD/search/iteration operations the parent file covers.

(in-package :cl-cc/php/stdlib/test)

(describe
  "PHP array_* builtins: reshaping and comparing"
  (it-sequential
    "array_chunk splits into fixed-size groups with a smaller final chunk"
    (let ((r (cl-cc/php/stdlib::%php-array-chunk (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4 5)) 2)))
      (expect (cl-cc/php:%php-count r) :to-be 3)
      (expect
        (cl-cc/php/arrays:%php-array-values-list (cl-cc/php:%php-array-ref r 0))
        :to-equal
        '(1 2))
      (expect
        (cl-cc/php/arrays:%php-array-values-list (cl-cc/php:%php-array-ref r 2))
        :to-equal
        '(5))))
  (it-sequential
    "array_pad extends right, left, or leaves longer arrays alone"
    (expect
      (cl-cc/php/arrays:%php-array-values-list
        (cl-cc/php/stdlib::%php-array-pad (cl-cc/php/arrays:%php-list-to-array '(1 2)) 4 0))
      :to-equal
      '(1 2 0 0))
    (expect
      (cl-cc/php/arrays:%php-array-values-list
        (cl-cc/php/stdlib::%php-array-pad (cl-cc/php/arrays:%php-list-to-array '(1 2)) -4 0))
      :to-equal
      '(0 0 1 2))
    (expect
      (cl-cc/php/arrays:%php-array-values-list
        (cl-cc/php/stdlib::%php-array-pad (cl-cc/php/arrays:%php-list-to-array '(1 2 3)) 2 0))
      :to-equal
      '(1 2 3)))
  (it-sequential
    "array_count_values tallies scalar occurrences"
    (let ((r
          (cl-cc/php/stdlib::%php-array-count-values
            (cl-cc/php/arrays:%php-list-to-array '("a" "b" "a" "c" "b" "a")))))
      (expect (cl-cc/php:%php-array-ref r "a") :to-be 3)
      (expect (cl-cc/php:%php-array-ref r "b") :to-be 2)
      (expect (cl-cc/php:%php-array-ref r "c") :to-be 1)))
  (it-sequential
    "array_sum and array_product operate over numeric values only"
    (expect
      (cl-cc/php/stdlib::%php-array-sum (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4)))
      :to-be
      10)
    (expect
      (cl-cc/php/stdlib::%php-array-product (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4)))
      :to-be
      24)
    (expect
      (cl-cc/php/stdlib::%php-array-sum
        (cl-cc/php:%php-array (list nil nil 1) (list nil nil "x") (list nil nil 2)))
      :to-be
      3))
  (it-sequential
    "array_diff and array_intersect compare by value"
    (expect
      (cl-cc/php/arrays:%php-array-values-list
        (cl-cc/php/stdlib::%php-array-diff
          (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4))
          (cl-cc/php/arrays:%php-list-to-array '(2 4))))
      :to-equal
      '(1 3))
    (expect
      (cl-cc/php/arrays:%php-array-values-list
        (cl-cc/php/stdlib::%php-array-intersect
          (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4))
          (cl-cc/php/arrays:%php-list-to-array '(2 4 6))))
      :to-equal
      '(2 4)))
  (it-sequential
    "array_udiff and array_uintersect compare via a user callback"
    (let ((cmp
          (lambda (a b)
            (- a b))))
      (expect
        (cl-cc/php/arrays:%php-array-values-list
          (cl-cc/php/stdlib::%php-array-udiff
            (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4))
            (cl-cc/php/arrays:%php-list-to-array '(2 4))
            cmp))
        :to-equal
        '(1 3))
      (expect
        (cl-cc/php/arrays:%php-array-values-list
          (cl-cc/php/stdlib::%php-array-uintersect
            (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4))
            (cl-cc/php/arrays:%php-list-to-array '(2 4 6))
            cmp))
        :to-equal
        '(2 4))))
  (it-sequential
    "array_column extracts a column, optionally re-indexed"
    (let* ((row1 (cl-cc/php:%php-array (list t "id" 1) (list t "name" "a")))
           (row2 (cl-cc/php:%php-array (list t "id" 2) (list t "name" "b")))
           (input (cl-cc/php/arrays:%php-list-to-array (list row1 row2))))
      (expect
        (cl-cc/php/arrays:%php-array-values-list (cl-cc/php/stdlib::%php-array-column input "name"))
        :to-equal
        '("a" "b"))
      (let ((r (cl-cc/php/stdlib::%php-array-column input "name" "id")))
        (expect (cl-cc/php:%php-array-ref r 1) :to-equal "a")
        (expect (cl-cc/php:%php-array-ref r 2) :to-equal "b"))))
  (it-sequential
    "array_combine pairs keys with values, array_flip swaps them"
    (let ((r
          (cl-cc/php/stdlib::%php-array-combine
            (cl-cc/php/arrays:%php-list-to-array '("a" "b"))
            (cl-cc/php/arrays:%php-list-to-array '(1 2)))))
      (expect (cl-cc/php:%php-array-ref r "a") :to-be 1)
      (expect (cl-cc/php:%php-array-ref r "b") :to-be 2))
    (let ((r (cl-cc/php/stdlib::%php-array-flip (cl-cc/php/arrays:%php-list-to-array '("x" "y" "z")))))
      (expect (cl-cc/php:%php-array-ref r "x") :to-be 0)
      (expect (cl-cc/php:%php-array-ref r "z") :to-be 2)))
  (it-sequential
    "array_fill and array_fill_keys build filled arrays"
    (let ((r (cl-cc/php/stdlib::%php-array-fill 5 3 "x")))
      (expect (cl-cc/php/arrays:%php-array-ordered-keys r) :to-equal '(5 6 7))
      (expect (cl-cc/php:%php-array-ref r 5) :to-equal "x"))
    (let ((r
          (cl-cc/php/stdlib::%php-array-fill-keys (cl-cc/php/arrays:%php-list-to-array '("a" "b")) 0)))
      (expect (cl-cc/php:%php-array-ref r "a") :to-be 0)
      (expect (cl-cc/php:%php-array-ref r "b") :to-be 0)))
  (it-sequential
    "array_splice removes a range and can insert a replacement"
    (let* ((a (cl-cc/php/arrays:%php-list-to-array '(1 2 3 4 5)))
           (removed (cl-cc/php/stdlib::%php-array-splice a 1 2)))
      (expect (cl-cc/php/arrays:%php-array-values-list removed) :to-equal '(2 3))
      (expect (cl-cc/php/arrays:%php-array-values-list a) :to-equal '(1 4 5)))
    (let* ((a (cl-cc/php/arrays:%php-list-to-array '(1 2 3)))
           (removed
          (cl-cc/php/stdlib::%php-array-splice a 1 1 (cl-cc/php/arrays:%php-list-to-array '(9 8)))))
      (expect (cl-cc/php/arrays:%php-array-values-list removed) :to-equal '(2))
      (expect (cl-cc/php/arrays:%php-array-values-list a) :to-equal '(1 9 8 3))))
  (it-sequential
    "array_replace overlays later arrays onto the first"
    (let ((r
          (cl-cc/php/stdlib::%php-array-replace
            (cl-cc/php:%php-array (list t "a" 1) (list t "b" 2))
            (cl-cc/php:%php-array (list t "b" 20) (list t "c" 30)))))
      (expect (cl-cc/php:%php-array-ref r "a") :to-be 1)
      (expect (cl-cc/php:%php-array-ref r "b") :to-be 20)
      (expect (cl-cc/php:%php-array-ref r "c") :to-be 30)))
  )
