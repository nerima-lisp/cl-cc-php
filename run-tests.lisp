;;;; run-tests.lisp
;;;;
;;;; CI entry point: load :cl-cc-php/test against the compiler systems and
;;;; runtime/test libraries it depends on, then run the suite on cl-weave.
;;;; Each sibling dependency is read from an env var so Nix can provide its
;;;; pinned source root; local runs use sibling checkouts as fallbacks.

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

(handler-case
    (asdf:test-system :cl-cc-php)
  (error (e)
    (format t "~&FAIL cl-cc-php/test: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))
