;;;; runtime-builtins-io.lisp — PHP system, environment, and process builtins.
;;;;
;;;; What is left after the rest of the runtime's I/O surface moved into
;;;; sibling files: interrogating the host (getenv, php_uname, PHP_INT_MAX,
;;;; memory_limit), ending or delaying the process (exit, sleep), decoding a
;;;; request query string, and draining an iterator. These share a dependency
;;;; on the host rather than on each other, which is why they are together and
;;;; not with the arrays, strings, or objects they operate on.
;;;;
;;;; The neighbours, all named for what they own:
;;;;   runtime-builtins-io-files.lisp     files and stream resources
;;;;   runtime-builtins-io-ini.lisp       INI settings and error handlers
;;;;   runtime-builtins-io-locale.lisp    locale and langinfo
;;;;   runtime-builtins-io-objects.lisp   object model and reflection
;;;;   runtime-builtins-io-autoload.lisp  class_* queries and SPL autoload
;;;;   runtime-builtins-io-image.lisp     image metadata
;;;;   runtime-builtins-io-output.lisp    output buffering and headers
;;;;   runtime-builtins-io-cookie-session.lisp  cookies and sessions

(in-package :cl-cc/php)

;;; ─── Shared Utilities ────────────────────────────────────────────────────────

(defun %php-path-string (value)
  (if (pathnamep value)
      (namestring value)
      (%php-stringify value)))
;;; ─── System / environment ───────────────────────────────────────────────────

(defun %php-getenv (varname &optional local-only)
  "PHP getenv: get environment variable."
  (declare (ignore local-only))
  (or (sb-ext:posix-getenv (%php-stringify varname)) nil))

(defun %php-putenv (setting)
  "PHP putenv: set environment variable."
  (let* ((s (%php-stringify setting))
         (eq-pos (position #\= s)))
    (if eq-pos
        (handler-case
            (progn
              (when (find-package :sb-posix)
                (funcall (intern "SETENV" :sb-posix) (subseq s 0 eq-pos) (subseq s (1+ eq-pos)) 1))
              t)
          (error () t))
        nil)))

(defun %php-php-uname (&optional (mode "a"))
  "PHP php_uname: OS information."
  (declare (ignore mode))
  "Darwin")

(defun %php-php-sapi-name ()
  "PHP php_sapi_name: return SAPI name."
  "cli")

(defun %php-php-version ()
  "PHP phpversion: return PHP version string."
  "8.5.0")

(defun %php-php-int-size ()
  "PHP PHP_INT_SIZE constant."
  8)

(defun %php-php-int-max ()
  "PHP PHP_INT_MAX constant."
  9223372036854775807)

(defun %php-php-int-min ()
  "PHP PHP_INT_MIN constant."
  -9223372036854775808)

(defun %php-php-float-max ()
  "PHP PHP_FLOAT_MAX constant."
  most-positive-double-float)

(defun %php-php-float-epsilon ()
  "PHP PHP_FLOAT_EPSILON constant."
  2.220446049250313d-16)

(defun %php-memory-limit-unit-multiplier (unit)
  "Return the multiplier for a PHP memory_limit suffix."
  (case (char-upcase unit)
    (#\K 1024)
    (#\M (expt 1024 2))
    (#\G (expt 1024 3))
    (#\T (expt 1024 4))
    (#\P (expt 1024 5))
    (#\E (expt 1024 6))
    (#\Z (expt 1024 7))
    (#\Y (expt 1024 8))
    (t 1)))

(defun %php-parse-memory-limit (value)
  "Parse a PHP memory_limit-style value into bytes or :unlimited."
  (let* ((text (string-trim '(#\Space #\Tab #\Newline #\Return)
                            (%php-stringify value))))
    (cond
      ((string= text "-1")
       (values nil t))
      ((zerop (length text))
       (values nil nil))
      (t
       (let* ((len (length text))
              (unit (and (> len 0)
                         (find (char-upcase (char text (1- len)))
                               "KMGTPEZY"
                               :test #'char=)))
              (number-text (if unit (subseq text 0 (1- len)) text)))
         (handler-case
             (let ((number (parse-integer (string-trim '(#\Space #\Tab #\Newline #\Return)
                                                       number-text)
                                          :junk-allowed nil)))
               (values (if unit
                           (* number (%php-memory-limit-unit-multiplier
                                      (char text (1- len))))
                           number)
                       nil))
           (error ()
             (values nil nil))))))))

(defun %php-memory-limit-exceeds-p (value max-value)
  "Return true when VALUE is larger than MAX-VALUE."
  (multiple-value-bind (value-bytes value-unlimited-p)
      (%php-parse-memory-limit value)
    (multiple-value-bind (max-bytes max-unlimited-p)
        (%php-parse-memory-limit max-value)
      (cond
        (max-unlimited-p nil)
        (value-unlimited-p t)
        ((or (null value-bytes) (null max-bytes)) nil)
        (t (> value-bytes max-bytes))))))
;;; ─── Process control ────────────────────────────────────────────────────────

(defun %php-exit (&optional (status 0))
  "PHP exit/die: terminate execution."
  (when (stringp status) (%php-output-write status))
  (sb-ext:exit :code (if (numberp status) status 0)))

(defun %php-die (&optional (status 0))
  "PHP die: alias for exit."
  (%php-exit status))

(defun %php-sleep (seconds)
  "PHP sleep: delay execution."
  (sleep seconds)
  0)

(defun %php-usleep (microseconds)
  "PHP usleep: delay in microseconds."
  (sleep (/ microseconds 1000000.0))
  nil)
;;; ─── Query-string decoding ──────────────────────────────────────────────────

(defun %php-parse-str (str &optional result)
  "PHP parse_str: parse URL query string into variables."
  (let ((parts (%php-explode "&" str))
        (target (or result (%php-make-array))))
    (dolist (pair (%php-array-values-list parts))
      (let ((eq-pos (search "=" pair)))
        (when eq-pos
          (%php-array-set target
                          (%php-urldecode (subseq pair 0 eq-pos))
                          (%php-urldecode (subseq pair (1+ eq-pos)))))))
    target))

(defun %php-http-build-query (data &optional numeric-prefix arg-separator enc-type)
  "PHP http_build_query: generate URL-encoded query string."
  (declare (ignore numeric-prefix enc-type))
  (let ((sep (if (and arg-separator (not (%php-null-p arg-separator)))
                 (%php-stringify arg-separator) "&"))
        (parts nil))
    (when (hash-table-p data)
      (dolist (pair (%php-array-pairs data))
        (push (concatenate 'string
                           (%php-urlencode (%php-stringify (car pair)))
                           "="
                           (%php-urlencode (%php-stringify (cdr pair))))
              parts)))
    (format nil "~{~A~^~A~}" (list (car (nreverse parts)) sep))))
;;; ─── Miscellaneous host services ────────────────────────────────────────────

(defun %php-microtime-float ()
  "PHP microtime(true): return current time as float."
  (coerce (- (get-internal-real-time) 0) 'double-float))
(defun %php-lcg-value ()
  "PHP lcg_value: a pseudo-random float in [0,1)."
  (random 1.0d0))
;;; ─── Iterator draining ──────────────────────────────────────────────────────

(defun %php-iterator-to-array (iter &optional (preserve-keys t))
  "PHP iterator_to_array: drain a Generator into a PHP array."
  (if (php-generator-p iter)
      (let ((result (%php-make-array)))
        (loop for i from 0
              while (%php-generator-valid iter)
              do (if (%php-truthy preserve-keys)
                     (%php-array-set result i (%php-generator-next iter))
                     (%php-array-set result (%php-array-next-auto-index result)
                                     (%php-generator-next iter))))
        result)
      iter))

(defun %php-iterator-count (iter)
  "PHP iterator_count: number of elements a Generator yields."
  (if (php-generator-p iter)
      (length (php-gen-values iter))
      (%php-count iter)))
