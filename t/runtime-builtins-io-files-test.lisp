;;;; runtime-builtins-io-files-test.lisp — src/runtime-builtins-io-files.lisp and
;;;; src/runtime-builtins-io-streams.lisp.

(in-package :cl-cc-php/test)

(defun %io-test-path (&optional (tag "file"))
  "Return a fresh, unique temp-file path string for I/O tests."
  (namestring
    (merge-pathnames
      (format nil "cl-cc-php-io-~A-~36R.txt" tag (random (expt 36 10)))
      (uiop:temporary-directory))))

(describe
  "PHP file and stream resource builtins"
  (it-sequential
    "file_put_contents writes and returns the byte count; file_get_contents reads it back"
    (let ((path (%io-test-path "rt")))
      (unwind-protect (progn
          (expect (cl-cc/php::%php-file-put-contents path "hello world") :to-be 11)
          (expect (cl-cc/php::%php-file-get-contents path) :to-equal "hello world"))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "file_get_contents honors offset and length, and returns nil for a missing file"
    (let ((path (%io-test-path "ol")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path "hello world")
          (expect (cl-cc/php::%php-file-get-contents path nil nil 6) :to-equal "world")
          (expect (cl-cc/php::%php-file-get-contents path nil nil 0 5) :to-equal "hello"))
        (ignore-errors (delete-file path)))
      (expect
        (cl-cc/php::%php-file-get-contents (%io-test-path "missing"))
        :to-be
        nil)))
  (it-sequential
    "file_put_contents with the append flag concatenates instead of truncating"
    (let ((path (%io-test-path "app")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path "abc")
          (cl-cc/php::%php-file-put-contents path "def" 8)
          (expect (cl-cc/php::%php-file-get-contents path) :to-equal "abcdef"))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "file_exists, is_file, is_readable, filesize, and unlink track a real file"
    (let ((path (%io-test-path "ex")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path "hello world")
          (expect (cl-cc/php::%php-file-exists path) :to-be-truthy)
          (expect (cl-cc/php::%php-is-file path) :to-be-truthy)
          (expect (cl-cc/php::%php-is-readable path) :to-be-truthy)
          (expect (cl-cc/php::%php-filesize path) :to-be 11)
          (expect (cl-cc/php::%php-unlink path) :to-be-truthy)
          (expect (cl-cc/php::%php-file-exists path) :to-be nil))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "is_dir is true for a directory and false for a nonexistent path"
    (expect
      (cl-cc/php::%php-is-dir (namestring (uiop:temporary-directory)))
      :to-be-truthy)
    (expect (cl-cc/php::%php-is-dir "/no/such/directory/here") :to-be nil))
  (it-sequential
    "file reads a file into an array of newline-terminated lines"
    (let ((path (%io-test-path "lines")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path (format nil "alpha~%beta~%"))
          (expect
            (cl-cc/php::%php-array-values-list (cl-cc/php::%php-file path))
            :to-equal
            (list (format nil "alpha~%") (format nil "beta~%"))))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "fopen/fread reads sequential chunks and sets EOF once the stream is exhausted"
    (let ((path (%io-test-path "read")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path "hello world")
          (let ((handle (cl-cc/php::%php-fopen path "r")))
            (unwind-protect (progn
                (expect (cl-cc/php::%php-feof handle) :to-be nil)
                (expect (cl-cc/php::%php-fread handle 5) :to-equal "hello")
                (expect (cl-cc/php::%php-fread handle 6) :to-equal " world")
                (expect (cl-cc/php::%php-fread handle 5) :to-equal "")
                (expect (cl-cc/php::%php-feof handle) :to-be-truthy))
              (cl-cc/php::%php-fclose handle))))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "fgets reads one line at a time and returns nil at end of file"
    (let ((path (%io-test-path "gets")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path (format nil "line1~%line2~%"))
          (let ((handle (cl-cc/php::%php-fopen path "r")))
            (unwind-protect (progn
                (expect (cl-cc/php::%php-fgets handle) :to-equal (format nil "line1~%"))
                (expect (cl-cc/php::%php-fgets handle) :to-equal (format nil "line2~%"))
                (expect (cl-cc/php::%php-fgets handle) :to-be nil)
                (expect (cl-cc/php::%php-feof handle) :to-be-truthy))
              (cl-cc/php::%php-fclose handle))))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "fwrite reports the characters written and fflush persists them to disk"
    (let ((path (%io-test-path "write")))
      (unwind-protect (progn
          (let ((handle (cl-cc/php::%php-fopen path "w")))
            (unwind-protect (progn
                (expect (cl-cc/php::%php-fwrite handle "payload") :to-be 7)
                (expect (cl-cc/php::%php-fflush handle) :to-be-truthy)
                (expect (cl-cc/php::%php-file-get-contents path) :to-equal "payload"))
              (cl-cc/php::%php-fclose handle))))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "ftell, fseek, and rewind move and report the stream position"
    (let ((path (%io-test-path "seek")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents path "hello world")
          (let ((handle (cl-cc/php::%php-fopen path "r")))
            (unwind-protect (progn
                (expect (cl-cc/php::%php-ftell handle) :to-be 0)
                (cl-cc/php::%php-fread handle 5)
                (expect (cl-cc/php::%php-ftell handle) :to-be 5)
                (expect (cl-cc/php::%php-rewind handle) :to-be 0)
                (expect (cl-cc/php::%php-ftell handle) :to-be 0)
                (expect (cl-cc/php::%php-fread handle 5) :to-equal "hello"))
              (cl-cc/php::%php-fclose handle))))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "copy duplicates a file and rename moves it"
    (let ((src (%io-test-path "src"))
          (dst (%io-test-path "dst"))
          (dst2 (%io-test-path "dst2")))
      (unwind-protect (progn
          (cl-cc/php::%php-file-put-contents src "data")
          (expect (cl-cc/php::%php-copy src dst) :to-be-truthy)
          (expect (cl-cc/php::%php-file-get-contents dst) :to-equal "data")
          (expect (cl-cc/php::%php-rename dst dst2) :to-be-truthy)
          (expect (cl-cc/php::%php-file-exists dst) :to-be nil)
          (expect (cl-cc/php::%php-file-get-contents dst2) :to-equal "data"))
        (ignore-errors (delete-file src))
        (ignore-errors (delete-file dst))
        (ignore-errors (delete-file dst2)))))
  (it-sequential
    "tempnam creates a fresh, existing file under the given directory"
    (let ((path (cl-cc/php::%php-tempnam (namestring (uiop:temporary-directory)) "pre")))
      (unwind-protect (progn
          (expect path :to-be-truthy)
          (expect (cl-cc/php::%php-file-exists path) :to-be-truthy))
        (ignore-errors (delete-file path)))))
  (it-sequential
    "basename returns the trailing component and strips a matching suffix"
    (expect (cl-cc/php::%php-basename "/foo/bar/baz.txt") :to-equal "baz.txt")
    (expect (cl-cc/php::%php-basename "/foo/bar/baz.txt" ".txt") :to-equal "baz")
    (expect (cl-cc/php::%php-basename "plain") :to-equal "plain"))
  (it-sequential
    "dirname strips one or more levels of trailing components"
    (expect (cl-cc/php::%php-dirname "/foo/bar/baz.txt") :to-equal "/foo/bar")
    (expect (cl-cc/php::%php-dirname "/foo/bar/baz.txt" 2) :to-equal "/foo")
    (expect (cl-cc/php::%php-dirname "noslash") :to-equal "."))
  (it-sequential
    "pathinfo returns components as an array and as individual option lookups"
    (let ((info (cl-cc/php::%php-pathinfo "/foo/bar.txt")))
      (expect (cl-cc/php::%php-array-ref info "dirname") :to-equal "/foo")
      (expect (cl-cc/php::%php-array-ref info "basename") :to-equal "bar.txt")
      (expect (cl-cc/php::%php-array-ref info "extension") :to-equal "txt")
      (expect (cl-cc/php::%php-array-ref info "filename") :to-equal "bar"))
    (expect (cl-cc/php::%php-pathinfo "/foo/bar.txt" 1) :to-equal "/foo")
    (expect (cl-cc/php::%php-pathinfo "/foo/bar.txt" 2) :to-equal "bar.txt")
    (expect (cl-cc/php::%php-pathinfo "/foo/bar.txt" 4) :to-equal "txt")
    (expect (cl-cc/php::%php-pathinfo "/foo/bar.txt" 8) :to-equal "bar"))
  (it-sequential
    "sys_get_temp_dir reports /tmp and is_link is always false in the CLI model"
    (expect (cl-cc/php::%php-sys-get-temp-dir) :to-equal "/tmp")
    (expect (cl-cc/php::%php-is-link "/anything") :to-be nil)))
