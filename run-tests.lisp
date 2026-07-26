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

(defvar *cl-prolog-root*
  (%env-or "CL_CC_PHP_CL_PROLOG_ROOT" "../cl-prolog"))

(defvar *cl-parser-kit-root*
  (%env-or "CL_CC_PHP_CL_PARSER_KIT_ROOT" "../cl-parser-kit"))

(defparameter *cl-cc-package-subdirs*
  ;; Every packages/<name>/ under the cl-cc checkout that :cl-cc-php/test
  ;; needs, transitively, to load: cl-cc-php's own four dependencies
  ;; (bootstrap ast parse vm) plus everything cl-cc-pipeline pulls in to
  ;; compile-and-run PHP source end-to-end for the e2e suites. Determined
  ;; empirically by loading :cl-cc-php/test and following each
  ;; MISSING-DEPENDENCY error to its system.
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
