;;;; coverage.lisp
;;;;
;;;; sb-cover entry point: report which lines of cl-cc-php's OWN source (not its
;;;; cl-cc/cl-weave dependencies) the test suite actually exercises.
;;;;
;;;; Instrumentation is a COMPILE-time property (SB-COVER:STORE-COVERAGE-DATA is
;;;; an (optimize ...) quality), so :cl-cc-php/test loads first — uninstrumented,
;;;; exactly as run-tests.lisp loads it — establishing every cross-package symbol
;;;; cl-cc-php's own files reference before those files are force-recompiled: a
;;;; premature :force t would recompile package.lisp before its cl-cc/ast,
;;;; cl-cc/bootstrap, and cl-cc/parse imports exist yet, turning ordinary
;;;; undefined-variable warnings into a fatal COMPILE-FILE-ERROR. Only :cl-cc-php
;;;; is then force-recompiled with the declaim on — ASDF considers already-
;;;; compiled fasls current and skips recompilation otherwise, which is how an
;;;; empty report happens silently — and reloaded, so its (now instrumented)
;;;; functions replace the ones RUN-TESTS below actually calls. Neither the test
;;;; suite's own forms nor its cl-cc-pipeline/cl-weave dependencies are ever
;;;; compiled under the declaim, so they never appear in the report: the question
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

(defvar *cl-cc-root* (%env-or "CL_CC_PHP_CL_CC_ROOT" "../cl-cc"))
(defvar *cl-weave-root* (%env-or "CL_CC_PHP_CL_WEAVE_ROOT" "../cl-weave"))
(defvar *cl-prolog-root* (%env-or "CL_CC_PHP_CL_PROLOG_ROOT" "../cl-prolog"))
(defvar *cl-parser-kit-root* (%env-or "CL_CC_PHP_CL_PARSER_KIT_ROOT" "../cl-parser-kit"))
(defvar *cl-json-kit-root* (%env-or "CL_CC_PHP_CL_JSON_KIT_ROOT" "../cl-json-kit"))
(defvar *cl-host-kit-root* (%env-or "CL_CC_PHP_CL_HOST_KIT_ROOT" "../cl-host-kit"))

(defparameter *cl-cc-package-subdirs*
  '("bootstrap" "ast" "parse" "vm" "runtime" "type" "mir" "optimize" "emit"
    "expand" "compile" "cps" "codegen" "target" "regalloc" "bytecode" "ir"
    "binary" "stdlib" "javascript" "pipeline"))

(defun %tree (pathname)
  (list :tree (uiop:ensure-directory-pathname pathname)))

(asdf:initialize-source-registry
 (list*
  :source-registry
  (%tree (uiop:ensure-directory-pathname *cl-weave-root*))
  (%tree (uiop:ensure-directory-pathname *cl-prolog-root*))
  (%tree (uiop:ensure-directory-pathname *cl-parser-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-json-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-host-kit-root*))
  (%tree (uiop:getcwd))
  (append
   (mapcar (lambda (subdir)
             (%tree (merge-pathnames
                     (format nil "packages/~A/" subdir)
                     (uiop:ensure-directory-pathname *cl-cc-root*))))
           *cl-cc-package-subdirs*)
   (list :ignore-inherited-configuration))))

;; Load everything uninstrumented first, exactly as run-tests.lisp does: every
;; cross-package symbol cl-cc-php's own files reference (from cl-cc/ast,
;; cl-cc/bootstrap, cl-cc/parse, and beyond) has to already be defined in the
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
