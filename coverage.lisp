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
(defvar *cl-prolog-kit-root* (%env-or "CL_CC_PHP_CL_PROLOG_KIT_ROOT" "../cl-prolog-kit"))
(defvar *cl-parser-kit-root* (%env-or "CL_CC_PHP_CL_PARSER_KIT_ROOT" "../cl-parser-kit"))
(defvar *cl-json-kit-root* (%env-or "CL_CC_PHP_CL_JSON_KIT_ROOT" "../cl-json-kit"))
(defvar *cl-host-kit-root* (%env-or "CL_CC_PHP_CL_HOST_KIT_ROOT" "../cl-host-kit"))

;; See run-tests.lisp's comment on the matching block: cl-cc.asd's own
;; :depends-on needs these 20 systems and the pinned cl-cc checkout no
;; longer provides them.
(defvar *cl-cc-ast-root* (%env-or "CL_CC_PHP_CL_CC_AST_ROOT" "../cl-cc-ast"))
(defvar *cl-cc-bootstrap-root*
  (%env-or "CL_CC_PHP_CL_CC_BOOTSTRAP_ROOT" "../cl-cc-bootstrap"))
(defvar *cl-cc-parse-root*
  (%env-or "CL_CC_PHP_CL_CC_PARSE_ROOT" "../cl-cc-parse"))
(defvar *cl-cc-vm-root* (%env-or "CL_CC_PHP_CL_CC_VM_ROOT" "../cl-cc-vm"))
(defvar *cl-cc-type-root*
  (%env-or "CL_CC_PHP_CL_CC_TYPE_ROOT" "../cl-cc-type"))
(defvar *cl-cc-binary-root*
  (%env-or "CL_CC_PHP_CL_CC_BINARY_ROOT" "../cl-cc-binary"))
(defvar *cl-cc-runtime-root*
  (%env-or "CL_CC_PHP_CL_CC_RUNTIME_ROOT" "../cl-cc-runtime"))
(defvar *cl-cc-mir-root* (%env-or "CL_CC_PHP_CL_CC_MIR_ROOT" "../cl-cc-mir"))
(defvar *cl-cc-codegen-native-root*
  (%env-or "CL_CC_PHP_CL_CC_CODEGEN_NATIVE_ROOT" "../cl-cc-codegen-native"))
(defvar *cl-cc-expand-root*
  (%env-or "CL_CC_PHP_CL_CC_EXPAND_ROOT" "../cl-cc-expand"))
(defvar *cl-cc-cps-root* (%env-or "CL_CC_PHP_CL_CC_CPS_ROOT" "../cl-cc-cps"))
(defvar *cl-cc-optimize-root*
  (%env-or "CL_CC_PHP_CL_CC_OPTIMIZE_ROOT" "../cl-cc-optimize"))
(defvar *cl-log-kit-root*
  (%env-or "CL_CC_PHP_CL_LOG_KIT_ROOT" "../cl-log-kit"))
(defvar *cl-date-kit-root*
  (%env-or "CL_CC_PHP_CL_DATE_KIT_ROOT" "../cl-date-kit"))
(defvar *cl-concurrent-kit-root*
  (%env-or "CL_CC_PHP_CL_CONCURRENT_KIT_ROOT" "../cl-concurrent-kit"))
(defvar *cl-boundary-kit-root*
  (%env-or "CL_CC_PHP_CL_BOUNDARY_KIT_ROOT" "../cl-boundary-kit"))
(defvar *cl-codec-kit-root*
  (%env-or "CL_CC_PHP_CL_CODEC_KIT_ROOT" "../cl-codec-kit"))
(defvar *cl-process-kit-root*
  (%env-or "CL_CC_PHP_CL_PROCESS_KIT_ROOT" "../cl-process-kit"))
(defvar *cl-regex-kit-root*
  (%env-or "CL_CC_PHP_CL_REGEX_KIT_ROOT" "../cl-regex-kit"))
(defvar *cl-tty-kit-root*
  (%env-or "CL_CC_PHP_CL_TTY_KIT_ROOT" "../cl-tty-kit"))

(defparameter *cl-cc-package-subdirs*
  '("compile" "pipeline" "stdlib"))

(defun %tree (pathname)
  (list :tree (uiop:ensure-directory-pathname pathname)))

(asdf:initialize-source-registry
 (list*
  :source-registry
  (%tree (uiop:ensure-directory-pathname *cl-weave-root*))
  (%tree (uiop:ensure-directory-pathname *cl-prolog-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-parser-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-json-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-host-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-ast-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-bootstrap-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-parse-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-vm-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-type-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-binary-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-runtime-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-mir-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-codegen-native-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-expand-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-cps-root*))
  (%tree (uiop:ensure-directory-pathname *cl-cc-optimize-root*))
  (%tree (uiop:ensure-directory-pathname *cl-log-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-date-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-concurrent-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-boundary-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-codec-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-process-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-regex-kit-root*))
  (%tree (uiop:ensure-directory-pathname *cl-tty-kit-root*))
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
