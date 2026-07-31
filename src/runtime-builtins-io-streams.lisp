;;;; runtime-builtins-io-streams.lisp — PHP stream resources: the fopen family.
;;;;
;;;; A PHP file handle is modelled as a hash table carrying the CL stream, the
;;;; mode it was opened with, its path, and an EOF flag. Everything here either
;;;; produces such a handle (fopen, STDIN/STDOUT/STDERR) or consumes one
;;;; (fread/fwrite/fgets/fseek/flock/...), which is what separates this file
;;;; from the path-based operations in runtime-builtins-io-files.lisp.
;;;;
;;;; flock is a compatibility model rather than a real advisory lock: the CLI
;;;; runtime tracks lock state per path in *php-file-locks* so that a program
;;;; that locks and unlocks correctly behaves, without pretending to coordinate
;;;; across processes.

(in-package :cl-cc/php)

(defun %php-standard-stream-handle (stream path mode)
  "Return a PHP stream handle for a dynamically bound CL standard stream."
  (let ((handle (%php-make-array)))
    (%php-array-set handle "__stream__" stream)
    (%php-array-set handle "__mode__" mode)
    (%php-array-set handle "__path__" path)
    (%php-array-set handle "__standard__" t)
    (%php-array-set handle "__eof__" nil)
    handle))

(defvar *php-file-locks* (make-hash-table :test #'equal)
  "Per-path flock state for the CLI compatibility model.")

(defun %php-file-lock-state (path)
  (or (gethash path *php-file-locks*)
      (setf (gethash path *php-file-locks*)
            (list :exclusive nil
                  :shared (make-hash-table :test #'eq)))))

(defun %php-file-lock-release-handle (handle)
  (let ((paths-to-remove '()))
    (maphash (lambda (path state)
               (let ((exclusive (getf state :exclusive))
                     (shared (getf state :shared)))
                 (when (eq exclusive handle)
                   (setf (getf state :exclusive) nil))
                 (when (hash-table-p shared)
                   (remhash handle shared))
                 (when (and (null (getf state :exclusive))
                            (hash-table-p shared)
                            (zerop (hash-table-count shared)))
                   (push path paths-to-remove))))
             *php-file-locks*)
    (dolist (path paths-to-remove)
      (remhash path *php-file-locks*))))

(defun %php-file-lock-compatible-p (state handle mode)
  (let ((exclusive (getf state :exclusive))
        (shared (getf state :shared)))
    (cond
      ((= mode 1)
       (or (null exclusive)
           (eq exclusive handle)))
      ((= mode 2)
       (and (or (null exclusive)
                (eq exclusive handle))
            (or (not (hash-table-p shared))
                (zerop (hash-table-count shared))
                (and (= (hash-table-count shared) 1)
                     (gethash handle shared)))))
      (t nil))))

(defun %php-file-lock-acquire (handle mode)
  (let* ((path (%php-array-ref handle "__path__"))
         (state (%php-file-lock-state path))
         (shared (getf state :shared)))
    (cond
      ((= mode 3)
       (%php-file-lock-release-handle handle)
       (%php-array-set handle "__lock__" nil)
       t)
      ((%php-file-lock-compatible-p state handle mode)
       (cond
         ((= mode 1)
          (setf (getf state :exclusive) nil)
          (setf (gethash handle shared) t)
          (%php-array-set handle "__lock__" mode)
          t)
         ((= mode 2)
          (when (hash-table-p shared)
            (remhash handle shared))
          (setf (getf state :exclusive) handle)
          (%php-array-set handle "__lock__" mode)
          t)))
      (t nil))))

(defun %php-stdin ()
  "PHP STDIN stream resource."
  (%php-standard-stream-handle *standard-input* "php://stdin" "r"))

(defun %php-stdout ()
  "PHP STDOUT stream resource."
  (%php-standard-stream-handle *standard-output* "php://stdout" "w"))

(defun %php-stderr ()
  "PHP STDERR stream resource."
  (%php-standard-stream-handle *error-output* "php://stderr" "w"))

(defun %php-fopen (filename mode &optional use-include-path context)
  "PHP fopen: open a file and return a file handle."
  (declare (ignore use-include-path context))
  (handler-case
      (let* ((path (%php-stringify filename))
             (m (%php-stringify mode))
             (direction (cond ((member m '("r" "rb") :test #'string=) :input)
                              ((member m '("w" "wb" "x" "xb") :test #'string=) :output)
                              ((member m '("a" "ab") :test #'string=) :output)
                              ((member m '("r+" "r+b") :test #'string=) :io)
                              (t :output)))
             (if-exists (cond ((member m '("a" "ab") :test #'string=) :append)
                              ((member m '("x" "xb") :test #'string=) :error)
                              (t :supersede)))
             (stream (open path :direction direction
                                :external-format :utf-8
                                :if-exists if-exists
                                :if-does-not-exist (if (eq direction :input) :error :create)))
             (handle (%php-make-array)))
        (%php-array-set handle "__stream__" stream)
        (%php-array-set handle "__mode__" m)
        (%php-array-set handle "__path__" path)
        (%php-array-set handle "__eof__" nil)
        handle)
    (error () nil)))

(defun %php-fclose (handle)
  "PHP fclose: close a file handle."
  (handler-case
      (let ((stream (%php-array-ref handle "__stream__")))
        (when (and stream (streamp stream))
          ;; %PHP-ARRAY-REF returns +PHP-NULL+ (a non-NIL symbol) for a
          ;; missing "__standard__" key, so an ordinary UNLESS never saw NIL
          ;; here and skipped CLOSE for every handle %PHP-FOPEN ever
          ;; returned — files opened via fopen() were never actually closed.
          (unless (%php-truthy (%php-array-ref handle "__standard__"))
            (close stream)))
        (%php-file-lock-release-handle handle)
        t)
    (error () nil)))

(defun %php-flock (handle operation)
  "PHP flock: maintain a minimal in-memory lock model for file handles."
  (handler-case
      (let* ((stream (%php-array-ref handle "__stream__"))
             (path (%php-array-ref handle "__path__"))
             (mode (%php-to-integer operation))
             (lock-mode (logand mode 3)))
        (if (and stream path)
            (%php-file-lock-acquire handle lock-mode)
            nil))
    (error () nil)))

(defun %php-fread (handle length)
  "PHP fread: read up to LENGTH bytes from file handle."
  (handler-case
      (let* ((stream (%php-array-ref handle "__stream__"))
             (buf (make-string length))
             (n (read-sequence buf stream)))
        (when (< n length)
          (%php-array-set handle "__eof__" t))
        (subseq buf 0 n))
    (error () "")))

(defun %php-fwrite (handle string &optional length)
  "PHP fwrite: write string to file handle."
  (handler-case
      (let* ((stream (%php-array-ref handle "__stream__"))
             (text (%php-stringify string))
             (to-write (if (and length (not (%php-null-p length)))
                           (subseq text 0 (min length (length text)))
                           text)))
        (write-string to-write stream)
        (length to-write))
    (error () nil)))

(defun %php-fputs (handle string &optional length)
  "PHP fputs: alias for fwrite."
  (%php-fwrite handle string length))

(defun %php-fgets (handle &optional length)
  "PHP fgets: read a line from file handle."
  (handler-case
      (let ((stream (%php-array-ref handle "__stream__")))
        (let ((line (read-line stream nil nil)))
          (if line
              (if (and length (not (%php-null-p length)))
                  (subseq (concatenate 'string line (string #\Newline)) 0
                          (min length (1+ (length line))))
                  (concatenate 'string line (string #\Newline)))
              (progn (%php-array-set handle "__eof__" t) nil))))
    (error () nil)))

(defun %php-fgetc (handle)
  "PHP fgetc: read a single character from file handle."
  (handler-case
      (let* ((stream (%php-array-ref handle "__stream__"))
             (ch (read-char stream nil nil)))
        (if ch (string ch)
            (progn (%php-array-set handle "__eof__" t) nil)))
    (error () nil)))

(defun %php-feof (handle)
  "PHP feof: check if end of file has been reached."
  (let ((eof (%php-array-ref handle "__eof__")))
    (and eof (%php-truthy eof))))

(defun %php-fflush (handle)
  "PHP fflush: flush output to file."
  (handler-case
      (let ((stream (%php-array-ref handle "__stream__")))
        (when (and stream (output-stream-p stream))
          (finish-output stream))
        t)
    (error () nil)))

(defun %php-fseek (handle offset &optional (whence 0))
  "PHP fseek: set the position in a file."
  (handler-case
      (let ((stream (%php-array-ref handle "__stream__")))
        (file-position stream
                       (case whence
                         (0 offset)             ; SEEK_SET
                         (1 (+ (file-position stream) offset))  ; SEEK_CUR
                         (2 nil)                ; SEEK_END - not easily portable
                         (t offset)))
        0)
    (error () -1)))

(defun %php-ftell (handle)
  "PHP ftell: return current file position."
  (handler-case
      (file-position (%php-array-ref handle "__stream__"))
    (error () nil)))

(defun %php-rewind (handle)
  "PHP rewind: set file position to beginning."
  (%php-fseek handle 0 0))

(defun %php-fgetcsv (handle &optional (length 0) (separator ",") (enclosure "\"") (escape "\\"))
  "PHP fgetcsv: parse CSV line from file."
  (declare (ignore length enclosure escape))
  (let ((line (%php-fgets handle)))
    (if line
        (%php-explode separator (string-right-trim '(#\Newline #\Return) line))
        nil)))

(defun %php-fputcsv (handle fields &optional (separator ",") (enclosure "\"") (escape "\\"))
  "PHP fputcsv: format line as CSV and write to file."
  (declare (ignore escape))
  (let* ((sep (%php-stringify separator))
         (enc (%php-stringify enclosure))
         (parts (mapcar (lambda (f)
                          (let ((s (%php-stringify f)))
                            (if (or (search sep s) (search enc s) (search (string #\Newline) s))
                                (concatenate 'string enc
                                             (cl:with-output-to-string (o)
                                               (loop for ch across s
                                                     do (when (string= (string ch) enc)
                                                          (write-string enc o))
                                                        (write-char ch o)))
                                             enc)
                                s)))
                        (%php-array-values-list fields)))
         ;; ~{~A~^~A~} over PARTS looked like a join, but ~^ only tests "is
         ;; there a next iteration", not "print the next argument" — with a
         ;; runtime SEP string rather than a literal separator baked into the
         ;; format string, this consumed exactly two list elements (the first
         ;; field, then SEP itself misread as a second field) and silently
         ;; dropped every field after the first.
         (line (concatenate 'string
                             (with-output-to-string (o)
                               (loop for (part . more) on parts
                                     do (write-string part o)
                                        (when more (write-string sep o))))
                             (string #\Newline))))
    (%php-fwrite handle line)
    (length line)))
