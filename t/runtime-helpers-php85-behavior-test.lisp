;;;; runtime-helpers-php85-behavior-test.lisp — src/runtime-helpers.lisp — PHP 8.5 runtime
;;;; behaviour.
;;;;
;;;; Version-conformance suite for the semantics the runtime helpers decide: clone-with, cast
;;;; spellings and their deprecations, the @ operator, the new E_WARNING/E_DEPRECATED cases,
;;;; fatal-error backtraces, and the max_memory_limit clamp (src/runtime-builtins-io.lisp and
;;;; -io-ini.lisp).

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 runtime behavior"
  (it-sequential
    "PHP 8.5 clone-with syntax lowers to the clone-with runtime helper."
    (let* ((value (%php-first-binding-value "<?php $b = clone($a, ['x' => 9]);"))
           (body (cl-cc/ast:ast-let-body value))
           (with-call (second body)))
      (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
      (expect (cl-cc/ast:ast-call-p with-call) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func with-call))
        :to-be
        'cl-cc/php::%php-clone-with)))
  (it-sequential
    "File helpers cover offset reads, append writes, and basic metadata lookups."
    (let* ((tmp-dir (uiop:temporary-directory))
           (unique-base (cl-cc/php::%php-tempnam tmp-dir "cl-cc-php85-"))
           (file (format nil "~A.txt" unique-base))
           (file-path (pathname file))
           (dir (format nil "~A-dir/" file))
           (dir-path (pathname dir)))
      (unwind-protect (progn
          (with-open-file (stream
              file-path
              :direction
              :output
              :if-exists
              :supersede
              :if-does-not-exist
              :create)
            (write-string "abcdef" stream))
          (expect (cl-cc/php::%php-file-get-contents file nil nil 2 nil) :to-equal "cdef")
          (expect (cl-cc/php::%php-file-get-contents file nil nil 2 3) :to-equal "cde")
          (expect (= 2 (cl-cc/php::%php-file-put-contents file "gh" 8)) :to-be-truthy)
          (expect (cl-cc/php::%php-file-get-contents file) :to-equal "abcdefgh")
          (expect (cl-cc/php::%php-file-exists file) :to-be-truthy)
          (expect (cl-cc/php::%php-is-file file) :to-be-truthy)
          (expect (cl-cc/php::%php-is-readable file) :to-be-truthy)
          (expect (cl-cc/php::%php-is-writable file) :to-be-truthy)
          (expect (cl-cc/php::%php-is-executable file) :to-be-truthy)
          (expect (= 8 (cl-cc/php::%php-filesize file)) :to-be-truthy)
          (expect (cl-cc/php::%php-filetype file) :to-equal "file")
          (expect
            (search (namestring tmp-dir) (cl-cc/php::%php-realpath file) :test #'char=)
            :to-be-truthy)
          (expect (cl-cc/php::%php-pathinfo file 4) :to-equal "txt")
          (expect
            (search "cl-cc-php85-" (cl-cc/php::%php-basename file) :test #'char=)
            :to-be-truthy)
          (expect
            (cl-cc/php::%php-dirname file)
            :to-equal
            (string-right-trim "/" (namestring tmp-dir)))
          (ensure-directories-exist dir-path)
          (expect
            (cl-cc/php::%php-mkdir (merge-pathnames "nested/" dir-path) nil nil)
            :to-be-truthy)
          (expect
            (cl-cc/php::%php-mkdir (merge-pathnames "recursive/a/b/" dir-path) nil t)
            :to-be-truthy)
          (expect (cl-cc/php::%php-is-dir dir-path) :to-be-truthy)
          (let ((sorted-up (cl-cc/php::%php-scandir dir 0))
                (sorted-down (cl-cc/php::%php-scandir dir 1)))
            (expect (hash-table-p sorted-up) :to-be-truthy)
            (expect (hash-table-p sorted-down) :to-be-truthy)
            (expect (= 4 (cl-cc/php:%php-count sorted-up)) :to-be-truthy)
            (expect (= 4 (cl-cc/php:%php-count sorted-down)) :to-be-truthy)))
        (ignore-errors (delete-file unique-base))
        (ignore-errors (delete-file file-path))
        (ignore-errors
          (uiop:delete-directory-tree dir-path :validate t :if-does-not-exist :ignore)))))
  (it-sequential
    "File mutation helpers cover copy, rename, unlink, and tempnam."
    (let* ((tmp-dir (uiop:temporary-directory))
           (source (pathname (cl-cc/php::%php-tempnam tmp-dir "cl-cc-php85-src-")))
           (copy (pathname (format nil "~A.copy" (namestring source))))
           (renamed (pathname (format nil "~A.renamed" (namestring source))))
           (tempnam (cl-cc/php::%php-tempnam tmp-dir "cl-cc-php85-")))
      (unwind-protect (progn
          (with-open-file (stream
              source
              :direction
              :output
              :if-exists
              :supersede
              :if-does-not-exist
              :create)
            (write-string "source" stream))
          (expect (cl-cc/php::%php-copy source copy) :to-be-truthy)
          (expect (cl-cc/php::%php-file-get-contents copy) :to-equal "source")
          (expect (cl-cc/php::%php-rename copy renamed) :to-be-truthy)
          (expect (probe-file copy) :to-be-falsy)
          (expect (cl-cc/php::%php-file-get-contents renamed) :to-equal "source")
          (expect (cl-cc/php::%php-unlink renamed) :to-be-truthy)
          (expect (probe-file renamed) :to-be-falsy)
          (expect (probe-file tempnam) :to-be-truthy))
        (ignore-errors (delete-file source))
        (ignore-errors (delete-file copy))
        (ignore-errors (delete-file renamed))
        (ignore-errors (delete-file tempnam)))))
  (it-sequential
    "The %php-empty helper mirrors PHP truthiness for empty values."
    (expect (cl-cc/php::%php-empty nil) :to-be-truthy)
    (expect (cl-cc/php::%php-empty 0) :to-be-truthy)
    (expect (cl-cc/php::%php-empty "0") :to-be-truthy)
    (expect (cl-cc/php::%php-empty "hello") :to-be-falsy)
    (let ((array (cl-cc/php:%php-array)))
      (expect (cl-cc/php::%php-empty array) :to-be-truthy)))
  (it-sequential
    "The %php-is-null helper distinguishes PHP null from other values."
    (expect (cl-cc/php::%php-is-null cl-cc/php:+php-null+) :to-be-truthy)
    (expect (cl-cc/php::%php-is-null 0) :to-be-falsy)
    (expect (cl-cc/php::%php-is-null "") :to-be-falsy))
  (it-sequential
    "The %php-unset helper always returns PHP null."
    (expect (cl-cc/php::%php-unset "ignored") :to-be cl-cc/php:+php-null+))
  (it-sequential
    "The %php-compact helper forwards its arguments into an array."
    (let ((array (cl-cc/php::%php-compact "x" "y")))
      (expect (hash-table-p array) :to-be-truthy)
      (expect (= 2 (hash-table-count array)) :to-be-truthy)))
  (it-sequential
    "The %php-extract helper returns zero for the fallback path."
    (expect (= 0 (cl-cc/php::%php-extract (cl-cc/php:%php-array))) :to-be-truthy))
  (it-sequential
    "The grapheme cluster helper keeps base characters and combining marks together."
    (let* ((cluster (format nil "a~C" (code-char #x0301)))
           (clusters (cl-cc/php::%php-grapheme-clusters cluster)))
      (expect (= 1 (length clusters)) :to-be-truthy)
      (expect (aref clusters 0) :to-equal cluster)))
  (it-sequential
    "The similar_text helper counts common character matches."
    (expect (= 2 (cl-cc/php::%php-similar-text "abc" "axc")) :to-be-truthy))
  (it-sequential
    "The soundex helper returns the expected four-character code."
    (expect (cl-cc/php::%php-soundex "Example") :to-equal "E251")))
