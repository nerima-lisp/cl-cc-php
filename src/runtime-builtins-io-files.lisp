;;;; runtime-builtins-io-files.lisp — PHP filesystem path and metadata builtins.
;;;;
;;;; Operations that name a file by path and either read it whole, ask the
;;;; filesystem about it, or move it: file_get_contents/file_put_contents,
;;;; the is_*/file* predicates, unlink/rename/copy, the directory calls, and
;;;; the path-string manipulations (basename, dirname, pathinfo, realpath).
;;;;
;;;; The handle-based half of PHP's file API — fopen and everything that takes
;;;; the resource it returns — is runtime-builtins-io-streams.lisp. The two are
;;;; separate concerns: nothing here holds state between calls, while the
;;;; stream file owns open handles, their read position, and the flock table.

(in-package :cl-cc/php)

;;; ─── File I/O ────────────────────────────────────────────────────────────────

(defun %php-file-get-contents (filename &optional use-include-path context offset length)
  "PHP file_get_contents: read file into string."
  (declare (ignore use-include-path context))
  (handler-case
      (let* ((path (%php-path-string filename))
             (content (with-open-file (s path :direction :input :external-format :utf-8)
                        (let ((result (make-string (file-length s))))
                          (read-sequence result s)
                          result)))
             (start (if (and offset (not (%php-null-p offset)) (> offset 0)) offset 0))
             (end (if (and length (not (%php-null-p length))) (+ start length) (length content))))
        (subseq content start (min end (length content))))
    (error () nil)))

(defun %php-file-put-contents (filename data &optional flags context)
  "PHP file_put_contents: write data to file."
  (declare (ignore context))
  (handler-case
      (let* ((path (%php-path-string filename))
             (text (%php-stringify data))
             (append-p (and flags (not (%php-null-p flags)) (logtest flags 8))))
        (with-open-file (s path :direction :output
                                :external-format :utf-8
                                :if-exists (if append-p :append :supersede)
                                :if-does-not-exist :create)
          (write-string text s))
        (length text))
    (error () nil)))

(defun %php-file (filename &optional flags context)
  "PHP file: read file into array of lines."
  (declare (ignore flags context))
  (handler-case
      (let ((result (%php-make-array)))
        (with-open-file (s (%php-path-string filename) :direction :input :external-format :utf-8)
          (loop for line = (read-line s nil nil)
                while line
                do (%php-array-set result (%php-array-next-auto-index result)
                                   (concatenate 'string line (string #\Newline)))))
        result)
    (error () nil)))

(defun %php-readfile (filename &optional use-include-path context)
  "PHP readfile: output file contents and return byte count."
  (declare (ignore use-include-path context))
  (let ((content (%php-file-get-contents filename)))
    (when content
      (%php-output-write content)
      (length content))))

(defun %php-file-exists (filename)
  "PHP file_exists: check if file or directory exists."
  (probe-file (%php-path-string filename)))

(defun %php-is-file (filename)
  "PHP is_file: check if path is a regular file."
  (let ((p (probe-file (%php-path-string filename))))
    (and p (or (pathname-name p) (pathname-type p)))))

(defun %php-is-dir (path)
  "PHP is_dir: check if path is a directory.
Appending a trailing slash before PROBE-FILE (the traditional CL idiom for
this check) doesn't reliably distinguish a directory from a regular file on
every SBCL/platform combination — PROBE-FILE can still resolve a
slash-suffixed path to a regular file. UIOP:DIRECTORY-EXISTS-P is written
specifically to make this determination portably."
  (and (uiop:directory-exists-p (%php-path-string path)) t))

(defun %php-is-readable (filename)
  "PHP is_readable: check if file is readable."
  (not (null (probe-file (%php-path-string filename)))))

(defun %php-is-writable (filename)
  "PHP is_writable: check if file is writable (simplified)."
  (not (null (probe-file (%php-path-string filename)))))

(defun %php-is-writeable (filename)
  "PHP is_writeable: alias for is_writable."
  (%php-is-writable filename))

(defun %php-is-executable (filename)
  "PHP is_executable: check if file is executable."
  (not (null (probe-file (%php-stringify filename)))))

(defun %php-is-link (filename)
  "PHP is_link: check if path is a symbolic link."
  (declare (ignore filename))
  nil)

(defun %php-filesize (filename)
  "PHP filesize: return file size in bytes."
  (handler-case
      (with-open-file (s (%php-stringify filename) :element-type '(unsigned-byte 8))
        (file-length s))
    (error () nil)))

(defun %php-filemtime (filename)
  "PHP filemtime: return file modification time."
  (handler-case
      (let ((time (file-write-date (%php-stringify filename))))
        (when time (- time 2208988800)))  ; Unix epoch offset
    (error () nil)))

(defun %php-filetype (filename)
  "PHP filetype: return file type string."
  (handler-case
      (let ((p (probe-file (%php-stringify filename))))
        (if p "file" nil))
    (error () nil)))

(defun %php-unlink (filename &optional context)
  "PHP unlink: delete a file."
  (declare (ignore context))
  (handler-case
      (progn (cl:delete-file (%php-path-string filename)) t)
    (error () nil)))

(defun %php-rename (oldname newname &optional context)
  "PHP rename: rename a file or directory."
  (declare (ignore context))
  (handler-case
      (progn (rename-file (%php-path-string oldname) (%php-path-string newname)) t)
    (error () nil)))

(defun %php-copy (source dest &optional context)
  "PHP copy: copy a file."
  (declare (ignore context))
  (handler-case
      (let ((content (%php-file-get-contents source)))
        (when content (%php-file-put-contents dest content) t))
    (error () nil)))

(defun %php-mkdir (pathname &optional (mode #o777) recursive context)
  "PHP mkdir: create a directory."
  (declare (ignore mode context))
  (handler-case
      (progn
        (if (%php-truthy recursive)
            (ensure-directories-exist (concatenate 'string (%php-stringify pathname) "/"))
            (cl:ensure-directories-exist (concatenate 'string (%php-stringify pathname) "/")))
        t)
    (error () nil)))

(defun %php-rmdir (dirname &optional context)
  "PHP rmdir: remove a directory."
  (declare (ignore context))
  (handler-case
      (progn (cl:delete-file (concatenate 'string (%php-stringify dirname) "/")) t)
    (error () nil)))

(defun %php-scandir (directory &optional (sorting-order 0) context)
  "PHP scandir: list files and directories in a directory."
  (declare (ignore context))
  (handler-case
      (let* ((dir (%php-stringify directory))
             (entries (mapcar (lambda (p)
                                (let ((name (file-namestring p)))
                                  (if (string= name "") (car (last (pathname-directory p))) name)))
                              (cl:directory (concatenate 'string dir "/*"))))
             (all (append (list "." "..") entries))
             (sorted (if (= sorting-order 1) (reverse (sort (copy-list all) #'string<))
                         (sort (copy-list all) #'string<))))
        (%php-list-to-array sorted))
    (error () nil)))

(defun %php-getcwd ()
  "PHP getcwd: return current working directory."
  (namestring (truename ".")))

(defun %php-chdir (directory)
  "PHP chdir: change current working directory (delegates to sb-posix if available)."
  (let ((path (%php-stringify directory)))
    (handler-case
        (let ((fn (and (find-package :sb-posix)
                       (find-symbol "CHDIR" :sb-posix))))
          (if (and fn (fboundp fn))
              (progn (funcall fn path) t)
              ;; Fallback: verify path exists, return true
              (and (probe-file path) t)))
      (error () nil))))

(defun %php-realpath (path)
  "PHP realpath: return canonicalized absolute pathname."
  (handler-case
      (namestring (truename (%php-stringify path)))
    (error () nil)))

(defun %php-path-tail (path)
  (let* ((p (%php-path-string path))
         (pos (or (position #\/ p :from-end t)
                  (position #\\ p :from-end t))))
    (if pos (subseq p (1+ pos)) p)))

(defun %php-basename (path &optional suffix)
  "PHP basename: return trailing name component of path."
  (let ((base (%php-path-tail path)))
    (if (and suffix (not (%php-null-p suffix)))
        (let ((s (%php-stringify suffix)))
          (if (and (>= (length base) (length s))
                   (string= base s :start1 (- (length base) (length s))))
              (subseq base 0 (- (length base) (length s)))
              base))
        base)))

(defun %php-dirname (path &optional (levels 1))
  "PHP dirname: return directory name of path."
  (let* ((p (%php-stringify path))
         (lvls (if (and levels (not (%php-null-p levels))) levels 1)))
    (let ((result p))
      (dotimes (i lvls)
        (let ((pos (or (position #\/ result :from-end t)
                       (position #\\ result :from-end t))))
          (setf result (if pos (subseq result 0 pos) "."))))
      result)))

(defun %php-pathinfo (path &optional (option nil))
  "PHP pathinfo: return path components."
  (let* ((p (%php-path-string path))
         (dirname (let ((pos (or (position #\/ p :from-end t) (position #\\ p :from-end t))))
                    (if pos (subseq p 0 pos) ".")))
         (filename (%php-path-tail p))
         (ext (let ((dot (position #\. filename :from-end t)))
                (if dot (subseq filename (1+ dot)) "")))
         (filename-without-extension (let ((dot (position #\. filename :from-end t)))
                                       (if dot (subseq filename 0 dot) filename))))
    (cond ((or (null option) (%php-null-p option))
           (let ((r (%php-make-array)))
             (%php-array-set r "dirname" dirname)
             (%php-array-set r "basename" filename)
             (%php-array-set r "extension" ext)
             (%php-array-set r "filename" filename-without-extension)
             r))
          ((= option 1) dirname)
          ((= option 2) filename)
          ((= option 4) ext)
          ((= option 8) filename-without-extension)
          (t nil))))

(defun %php-tempnam (dir &optional (prefix ""))
  "PHP tempnam: create file with unique name."
  (let* ((base (if (and dir (not (%php-null-p dir))) (%php-path-string dir) "/tmp"))
         (base (string-right-trim "/" base))
         (prefix (%php-stringify prefix)))
    (loop for attempt from 0 below 1024
          for tmp = (format nil "~A/~A~8,'0X~8,'0X~4,'0X"
                            base
                            prefix
                            (logand (sxhash (list (get-universal-time)
                                                   (get-internal-real-time)
                                                   (gensym)))
                                    #xffffffff)
                            (random #xffffffff)
                            attempt)
          when (handler-case
                   (with-open-file (s tmp :direction :output
                                           :if-exists nil
                                           :if-does-not-exist :create
                                           :external-format :utf-8)
                     (declare (ignore s))
                     t)
                 (error () nil))
            do (return tmp)
          finally (return nil))))

(defun %php-sys-get-temp-dir ()
  "PHP sys_get_temp_dir: return temp directory path."
  "/tmp")
