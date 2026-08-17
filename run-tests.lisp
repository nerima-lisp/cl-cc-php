;;;; run-tests.lisp
;;;;
;;;; CI entry point: load :cl-cc-php/test against the still-monorepo-internal
;;;; systems it depends on (bootstrap/ast/parse/vm and, transitively via
;;;; cl-cc-pipeline for the e2e suites, most of cl-cc) and run the suite on
;;;; cl-weave. cl-cc-php is not dependency-free (see README's Status section),
;;;; so unlike a leaf system this can't just ASDF:LOAD-SYSTEM itself — every
;;;; dependency root has to be registered first.
;;;;
;;;; Each dependency root is read from an env var so the Nix derivation can
;;;; hand in exact flake-input store paths; CL-CC-PHP-DEFAULT-CL-CC-ROOT below
;;;; is only a convenience fallback for running this script directly against
;;;; sibling checkouts outside Nix (see README's Testing section).

(require :asdf)

(defparameter *repo-root*
  (uiop:pathname-directory-pathname
   (or *load-truename* *load-pathname* (uiop:getcwd)))
  "This checkout's root, used to anchor the sibling fallbacks below.")

(defun %env-or (var default)
  "Return VAR's value, or DEFAULT resolved against this checkout.

ASDF's source registry rejects a relative pathname, so the sibling fallbacks
cannot be handed over as the bare \"../cl-weave\" strings they are written as —
running this script outside Nix died on \"Invalid pathname #P\\\"../cl-weave/\\\":
Expected an absolute pathname\" before loading anything. Under Nix every root
arrives through its env var and this branch is not taken."
  (or (uiop:getenv var)
      (namestring
       (uiop:ensure-absolute-pathname
        (uiop:ensure-directory-pathname default)
        *repo-root*))))

(defvar *cl-cc-root*
  (%env-or "CL_CC_PHP_CL_CC_ROOT" "../cl-cc"))

(defvar *cl-weave-root*
  (%env-or "CL_CC_PHP_CL_WEAVE_ROOT" "../cl-weave"))

(defvar *cl-prolog-kit-root*
  (%env-or "CL_CC_PHP_CL_PROLOG_KIT_ROOT" "../cl-prolog-kit"))

(defvar *cl-parser-kit-root*
  (%env-or "CL_CC_PHP_CL_PARSER_KIT_ROOT" "../cl-parser-kit"))

(defvar *cl-json-kit-root*
  (%env-or "CL_CC_PHP_CL_JSON_KIT_ROOT" "../cl-json-kit"))

(defvar *cl-host-kit-root*
  (%env-or "CL_CC_PHP_CL_HOST_KIT_ROOT" "../cl-host-kit"))

;; cl-cc.asd itself says why these can't come from the cl-cc checkout above:
;; "cl-cc-bootstrap, cl-cc-vm, cl-cc-ast, cl-cc-type, cl-cc-binary,
;; cl-cc-runtime, cl-cc-mir and cl-cc-target ... live in the standalone
;; repositories of the same name under nerima-lisp and reach this build as
;; flake.nix inputs" -- that obligation falls on cl-cc-php too. Empirically
;; (loading :cl-cc-php/test and following each MISSING-DEPENDENCY error to
;; its system) the closure is wider than those eight: cl-cc-parse/optimize/
;; expand/cps, cl-cc-codegen-native (which bundles cl-cc-codegen/emit/
;; regalloc), and cl-log-kit's own dependency chain (cl-date-kit,
;; cl-concurrent-kit -> cl-boundary-kit, cl-process-kit -> cl-codec-kit) are
;; equally absent from the tree.
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
;; Also provides cl-cc-target (see its own cl-cc-target.asd, nested in this
;; same tree).
(defvar *cl-cc-mir-root* (%env-or "CL_CC_PHP_CL_CC_MIR_ROOT" "../cl-cc-mir"))
;; Also provides cl-cc-codegen, cl-cc-emit and cl-cc-regalloc, each a
;; separate .asd nested under codegen/, emit/ and regalloc/.
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
  ;; What's left under packages/<name>/ in the cl-cc checkout once the 20
  ;; standalone systems above are accounted for: cl-cc-compile (itself
  ;; :depends-on cl-cc-target/regalloc directly), cl-cc-pipeline (the e2e
  ;; entry point cl-cc-php/test depends on), and cl-cc-stdlib.
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

(handler-case
    (progn
      (asdf:load-system :cl-cc-php/test)
      ;; RUN-TESTS signals an error on any failure rather than returning NIL,
      ;; so reaching past this call at all already means the suite is green.
      (funcall (find-symbol "RUN-TESTS" "CL-CC-PHP/TEST")))
  (error (e)
    (format t "~&FAIL cl-cc-php/test: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))
