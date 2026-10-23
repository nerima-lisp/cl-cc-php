;;;; coverage.lisp
;;;;
;;;; sb-cover entry point: report which lines of cl-cc-php's own source the
;;;; test suite exercises.
;;;;
;;;; Instrumentation is a COMPILE-time property (SB-COVER:STORE-COVERAGE-DATA is
;;;; an (optimize ...) quality), so :cl-cc-php/test loads first — uninstrumented,
;;;; exactly as run-tests.lisp loads it — establishing every cross-package symbol
;;;; cl-cc-php's own files reference before those files are force-recompiled: a
;;;; premature :force t would recompile package.lisp before its cl-cc/ast,
;;;; cl-cc/bootstrap, cl-cc/parse, and cl-cc/vm imports exist yet, turning
;;;; ordinary undefined-variable warnings into a fatal COMPILE-FILE-ERROR.
;;;; Only :cl-cc-php is force-recompiled under the declaim. ASDF skips current
;;;; fasls, and a normal load would leave them uninstrumented. Reloading its
;;;; instrumented files replaces the functions RUN-TESTS calls below. The test suite
;;;; and its dependencies are not compiled under the declaim, so they never
;;;; appear in the report: the question
;;;; this answers is "how much of cl-cc-php's implementation do the tests reach",
;;;; not "how much of the test suite runs".
;;;;
;;;; Shares its dependency-root environment variables and sibling-checkout
;;;; fallbacks with run-tests.lisp; see that file's comments for why each exists.

(require :asdf)
(require :sb-cover)

(defparameter *repo-root*
  (uiop:pathname-directory-pathname
   (or *load-truename* *load-pathname* (uiop:getcwd))))

(defun %env-or (var default)
  (or (uiop:getenv var)
      (namestring
       (uiop:ensure-absolute-pathname
        (uiop:ensure-directory-pathname default)
        *repo-root*))))

(defparameter *cl-cc-roots*
  (list
   (%env-or "CL_CC_PHP_CL_CC_BOOTSTRAP_ROOT" "../cl-cc-bootstrap")
   (%env-or "CL_CC_PHP_CL_CC_AST_ROOT" "../cl-cc-ast")
   (%env-or "CL_CC_PHP_CL_CC_PARSE_ROOT" "../cl-cc-parse")
   (%env-or "CL_CC_PHP_CL_CC_RUNTIME_ROOT" "../cl-cc-runtime")
   (%env-or "CL_CC_PHP_CL_CC_VM_ROOT" "../cl-cc-vm")))
(defparameter *cl-support-roots*
  (list
   (%env-or "CL_CC_PHP_CL_WEAVE_ROOT" "../cl-weave")
   (%env-or "CL_CC_PHP_CL_PARSER_KIT_ROOT" "../cl-parser-kit")
   (%env-or "CL_CC_PHP_CL_REGEX_KIT_ROOT" "../cl-regex-kit")
   (%env-or "CL_CC_PHP_CL_TTY_KIT_ROOT" "../cl-tty-kit")
   (%env-or "CL_CC_PHP_CL_LOG_KIT_ROOT" "../cl-log-kit")
   (%env-or "CL_CC_PHP_CL_PROCESS_KIT_ROOT" "../cl-process-kit")
   (%env-or "CL_CC_PHP_CL_CODEC_KIT_ROOT" "../cl-codec-kit")
   (%env-or "CL_CC_PHP_CL_CONCURRENT_KIT_ROOT" "../cl-concurrent-kit")
   (%env-or "CL_CC_PHP_CL_BOUNDARY_KIT_ROOT" "../cl-boundary-kit")
   (%env-or "CL_CC_PHP_CL_DATE_KIT_ROOT" "../cl-date-kit")
   (%env-or "CL_CC_PHP_CL_JSON_KIT_ROOT" "../cl-json-kit")
   (%env-or "CL_CC_PHP_CL_HOST_KIT_ROOT" "../cl-host-kit")))
(defun %tree (pathname)
  (list :tree (uiop:ensure-directory-pathname pathname)))

(asdf:initialize-source-registry
 (list*
  :source-registry
  (append
   (mapcar (function %tree) *cl-cc-roots*)
   (mapcar (function %tree) *cl-support-roots*)
   (list
    (%tree (uiop:getcwd))
    :ignore-inherited-configuration))))

;; Load everything uninstrumented first, exactly as run-tests.lisp does: every
;; cross-package symbol cl-cc-php's own files reference from its compiler and
;; runtime dependencies has to already be defined in the
;; image before those files are force-recompiled below, or the recompile
;; itself hits "undefined variable" warnings that UIOP promotes to a fatal
;; COMPILE-FILE-ERROR.
(asdf:load-system :cl-cc-php/test)

;; Only cl-cc-php's own source is instrumented, and only it is force-recompiled
;; (and reloaded, redefining its functions in the image) so the declaim
;; actually takes effect on every one of its files. WARNING is muffled for this
;; one load: src/package.lisp's DEFPACKAGE form is revisited a second time
;; here, after other cl-cc-php files (already loaded above) have EXPORTed
;; additional symbols beyond what that form's own :export list names, and
;; SBCL's *ON-PACKAGE-VARIANCE* signals that as a WARNING on every
;; recompilation, not only the first — harmless here since nothing actually
;; changed about the package between the two loads.
(proclaim '(optimize sb-cover:store-coverage-data))
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :cl-cc-php :force t))
(proclaim '(optimize (sb-cover:store-coverage-data 0)))

(handler-case
    (funcall (find-symbol "RUN-TESTS" "CL-CC-PHP/TEST"))
  (error (e)
    (format t "~&coverage.lisp: test suite failed: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(let ((report-dir
        (uiop:ensure-directory-pathname
         (or (uiop:getenv "CL_CC_PHP_COVERAGE_OUT") "coverage-report/"))))
  (ensure-directories-exist report-dir)
  (sb-cover:report report-dir))

(format t "~&coverage.lisp: report written.~%")
(finish-output)
