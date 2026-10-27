;;;; runtime-builtins-io-locale.lisp — PHP locale and langinfo builtins.
;;;;
;;;; nl_langinfo plus the PHP 8.5 Locale helpers (addLikelySubtags,
;;;; minimizeSubtags, isRightToLeft). All of them answer questions about a
;;;; locale identifier and none of them touch the host locale, so this is a
;;;; pure table lookup over the data in runtime-builtins-io-data.lisp.

(in-package #:cl-cc/php/stdlib)

(defun %php-nl-langinfo (item)
  "PHP nl_langinfo: return deterministic locale metadata for ITEM."
  (let* ((entry (if (stringp item)
                    (find (string-upcase item) +php-nl-langinfo-items+
                          :test #'string= :key #'first)
                    (find (%php-to-integer item) +php-nl-langinfo-items+
                          :test #'= :key #'second))))
    (if entry
        (third entry)
        "")))

(defun %php-locale-normalized-id (locale)
  "Return a lowercase BCP-47-ish locale id without encoding/modifier suffixes."
  (let* ((raw (%php-stringify locale))
         (cut (reduce #'min
                      (remove nil (list (position #\. raw) (position #\@ raw)))
                      :initial-value (length raw))))
    (string-downcase (substitute #\- #\_ (subseq raw 0 cut)))))

(defun %php-locale-subtags (locale-id)
  (loop with start = 0
        for pos = (position #\- locale-id :start start)
        collect (subseq locale-id start pos)
        while pos
        do (setf start (1+ pos))))

(defun %php-locale-add-likely-subtags (locale)
  "PHP 8.5 Locale::addLikelySubtags compatibility helper."
  (let ((id (%php-locale-normalized-id locale)))
    (or (cdr (assoc id *php-locale-likely-subtags* :test #'string=))
        (if (position #\- id)
            id
            (format nil "~A-Latn-US" id)))))

(defun %php-locale-minimize-subtags (locale)
  "PHP 8.5 Locale::minimizeSubtags compatibility helper."
  (let* ((id (%php-locale-normalized-id locale))
         (likely (rassoc id *php-locale-likely-subtags* :test #'string-equal)))
    (or (car likely)
        (first (%php-locale-subtags id))
        id)))

(defun %php-locale-is-right-to-left (locale)
  "PHP 8.5 locale_is_right_to_left / Locale::isRightToLeft helper."
  (let* ((id (%php-locale-normalized-id locale))
         (subtags (%php-locale-subtags id))
         (primary (first subtags)))
    (and primary
         (or (member primary
                     '("ar" "arc" "ckb" "dv" "fa" "he" "iw" "ks" "lrc"
                       "mzn" "nqo" "pnb" "ps" "sd" "syr" "ug" "ur" "yi")
                     :test #'string=)
             (some (lambda (subtag)
                     (member subtag '("arab" "hebr" "nkoo" "syrc" "thaa")
                             :test #'string=))
                   subtags)))))
(defun %PARSER-PHP-LOCALE-STATIC-MEMBER-LOWERER (object member args method-p)
  (let ((class-p
          (and (ast-var-p object)
               (string= (string-upcase (symbol-name (ast-var-name object)))
                        "LOCALE")))
        (member-name (string-upcase (symbol-name member))))
    (if (and method-p class-p)
        (let ((key (cond
                     ((string= member-name "ISRIGHTTOLEFT")
                      :locale-is-right-to-left)
                     ((string= member-name "ADDLIKELYSUBTAGS")
                      :locale-add-likely-subtags)
                     ((string= member-name "MINIMIZESUBTAGS")
                      :locale-minimize-subtags))))
          (if key
              (progn
                (unless (= (length args) 1)
                  (error
                   (cond
                     ((eq key :locale-is-right-to-left)
                      "PHP parse error: Locale::isRightToLeft() expects exactly 1 argument")
                     ((eq key :locale-add-likely-subtags)
                      "PHP parse error: Locale::addLikelySubtags() expects exactly 1 argument")
                     (t
                      "PHP parse error: Locale::minimizeSubtags() expects exactly 1 argument"))))
                (values
                 (make-ast-call
                  :func (make-ast-var :name (%PARSER-PHP-RUNTIME-SYMBOL key))
                  :args args)
                 t))
              (values nil nil)))
        (values nil nil))))

(eval-when (:load-toplevel :execute)
  (register-php-runtime-symbol :locale-is-right-to-left '%php-locale-is-right-to-left)
  (register-php-runtime-symbol :locale-add-likely-subtags '%php-locale-add-likely-subtags)
  (register-php-runtime-symbol :locale-minimize-subtags '%php-locale-minimize-subtags)
  (register-php-expression-static-member-lowerer
   #'%PARSER-PHP-LOCALE-STATIC-MEMBER-LOWERER))
