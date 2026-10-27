(in-package :cl-cc/php/stdlib/test)

(describe "PHP standard library tests"
  (it-sequential
    "File helpers cover offset reads, append writes, and basic metadata lookups."
    (let* ((tmp-dir (uiop:temporary-directory))
           (unique-base (cl-cc/php/stdlib:%php-tempnam tmp-dir "cl-cc-php85-"))
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
          (expect (cl-cc/php/stdlib:%php-file-get-contents file nil nil 2 nil) :to-equal "cdef")
          (expect (cl-cc/php/stdlib:%php-file-get-contents file nil nil 2 3) :to-equal "cde")
          (expect (= 2 (cl-cc/php/stdlib:%php-file-put-contents file "gh" 8)) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-file-get-contents file) :to-equal "abcdefgh")
          (expect (cl-cc/php/stdlib:%php-file-exists file) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-is-file file) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-is-readable file) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-is-writable file) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-is-executable file) :to-be-truthy)
          (expect (= 8 (cl-cc/php/stdlib:%php-filesize file)) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-filetype file) :to-equal "file")
          (expect
            (search (namestring tmp-dir) (cl-cc/php/stdlib:%php-realpath file) :test #'char=)
            :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-pathinfo file 4) :to-equal "txt")
          (expect
            (search "cl-cc-php85-" (cl-cc/php/stdlib:%php-basename file) :test #'char=)
            :to-be-truthy)
          (expect
            (cl-cc/php/stdlib:%php-dirname file)
            :to-equal
            (string-right-trim "/" (namestring tmp-dir)))
          (ensure-directories-exist dir-path)
          (expect
            (cl-cc/php/stdlib:%php-mkdir (merge-pathnames "nested/" dir-path) nil nil)
            :to-be-truthy)
          (expect
            (cl-cc/php/stdlib:%php-mkdir (merge-pathnames "recursive/a/b/" dir-path) nil t)
            :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-is-dir dir-path) :to-be-truthy)
          (let ((sorted-up (cl-cc/php/stdlib:%php-scandir dir 0))
                (sorted-down (cl-cc/php/stdlib:%php-scandir dir 1)))
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
           (source (pathname (cl-cc/php/stdlib:%php-tempnam tmp-dir "cl-cc-php85-src-")))
           (copy (pathname (format nil "~A.copy" (namestring source))))
           (renamed (pathname (format nil "~A.renamed" (namestring source))))
           (tempnam (cl-cc/php/stdlib:%php-tempnam tmp-dir "cl-cc-php85-")))
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
          (expect (cl-cc/php/stdlib:%php-copy source copy) :to-be-truthy)
          (expect (cl-cc/php/stdlib:%php-file-get-contents copy) :to-equal "source")
          (expect (cl-cc/php/stdlib:%php-rename copy renamed) :to-be-truthy)
          (expect (probe-file copy) :to-be-falsy)
          (expect (cl-cc/php/stdlib:%php-file-get-contents renamed) :to-equal "source")
          (expect (cl-cc/php/stdlib:%php-unlink renamed) :to-be-truthy)
          (expect (probe-file renamed) :to-be-falsy)
          (expect (probe-file tempnam) :to-be-truthy))
        (ignore-errors (delete-file source))
        (ignore-errors (delete-file copy))
        (ignore-errors (delete-file renamed))
        (ignore-errors (delete-file tempnam))))))
