;;;; grammar-test.lisp — token-stream helpers in src/grammar.lisp.

(in-package :cl-cc/php/syntax/test)

(describe
  "PHP grammar token-stream helpers"
  (defun %php-ts (tokens)
    (cl-cc/php/syntax:make-php-token-stream :tokens tokens :source "" :diagnostics nil))
  (it-sequential
    "php-grammar-token-stream-peek-advance"
    (let* ((ts
          (%php-ts
            (list (list :type :T-IDENT :value "foo") (list :type :T-EOF :value nil)))))
      (expect (cl-cc/php/syntax:php-ts-peek-type ts) :to-be :T-IDENT)
      (expect (cl-cc/php/syntax:php-ts-peek-value ts) :to-equal "foo")
      (expect
        (cl-cc/php/syntax:php-ts-advance ts)
        :to-equal
        (list :type :T-IDENT :value "foo"))
      (expect (cl-cc/php/syntax:php-ts-peek-type ts) :to-be :T-EOF)))
  (it-sequential
    "php-grammar-token-stream-skip-semis"
    (let* ((ts
          (%php-ts
            (list
              (list :type :T-SEMI :value ";")
              (list :type :T-SEMI :value ";")
              (list :type :T-IDENT :value "x")
              (list :type :T-EOF :value nil)))))
      (cl-cc/php/syntax:php-ts-skip-semis ts)
      (expect (cl-cc/php/syntax:php-ts-peek-type ts) :to-be :T-IDENT)
      (expect (cl-cc/php/syntax:php-ts-peek-value ts) :to-equal "x")))
  (it-sequential
    "php-grammar-token-stream-at-end"
    (expect (cl-cc/php/syntax:php-ts-at-end-p (%php-ts nil)) :to-be-truthy)
    (expect
      (cl-cc/php/syntax:php-ts-at-end-p (%php-ts (list (list :type :T-EOF :value nil))))
      :to-be-truthy))
  (it-sequential
    "php-parser-qualified-name-rejects-single-token-namespace-separators"
    (let ((%%signaled1 nil))
      (handler-case (progn
          (cl-cc/php/syntax:php-parse-qualified-name
            (list (cl-cc/php/syntax::make-php-token :T-IDENT "Vendor\\Thing"))))
        (error ()
          (setf %%signaled1 t)))
      (expect %%signaled1 :to-be-truthy))))
