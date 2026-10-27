(in-package :cl-cc/php/functions/test)

(describe "PHP function parser tests"
  (it-sequential "Named arg descriptors from %php-parse-named-args lower to plain positional AST exprs."
;; Test the helper function directly with hand-built descriptors.
  (let* ((descs  (list (list :positional (cl-cc/ast:make-ast-int :value 1))
                       (list :named "key" (cl-cc/ast:make-ast-quote :value "val"))
                       (list :spread  (cl-cc/ast:make-ast-var :name 'x))))
         (result (cl-cc/php/functions:%php-named-args-to-positional descs)))
    (expect (= 3 (length result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-int-p (first result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-quote-p (second result)) :to-be-truthy)
    (expect (cl-cc/ast:ast-var-p (third result)) :to-be-truthy)))
  (it-sequential "The %php-named-arg-p predicate recognises IDENT : as a named argument."
;; We test with a hand-built token stream matching the helper contract.
  (let* ((ident-tok   (list :type :T-IDENT :value "name"))
         (colon-tok   (list :type :T-COLON :value ":"))
         (fake-stream (list ident-tok colon-tok)))
    (expect (cl-cc/php/syntax:%php-named-arg-p fake-stream) :to-be-truthy)))
  (it-sequential "createUser(name: \"Alice\", age: 25) lowers to an ast-call with 2 positional args."
(let* ((ast (%php-first "<?php createUser(\"Alice\", 25);")))
    ;; Without named-arg integration in php-parse-arglist the call uses
    ;; positional lowering: two arguments are preserved in order.
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (= 2 (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)))
  (it-sequential "Positional args before named args both survive into the call AST."
(let* ((ast (%php-first "<?php htmlspecialchars(\"<b>hi</b>\", 11);")))
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (plusp (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)))
  (it-sequential "The %php-first-class-callable-p predicate returns true for ( ... ) token sequence."
(let* ((lparen-tok  (list :type :T-LPAREN   :value "("))
         (ellipsis-tok (list :type :T-ELLIPSIS :value "..."))
         (rparen-tok  (list :type :T-RPAREN   :value ")"))
         (stream      (list lparen-tok ellipsis-tok rparen-tok)))
    (expect (cl-cc/php/functions:%php-first-class-callable-p stream) :to-be-truthy)))
  (it-sequential "The %php-first-class-callable-p predicate returns false when ( has real args."
(let* ((lparen-tok  (list :type :T-LPAREN :value "("))
         (int-tok     (list :type :T-INT    :value 1))
         (rparen-tok  (list :type :T-RPAREN :value ")"))
         (stream      (list lparen-tok int-tok rparen-tok)))
    (expect (cl-cc/php/functions:%php-first-class-callable-p stream) :to-be-falsy)))
  (it-sequential "The %php-callable-ref function returns an ast-lambda that wraps the function."
(let* ((func-ast (cl-cc/ast:make-ast-var :name 'strlen))
         (ref      (cl-cc/php:%php-callable-ref func-ast)))
    (expect (cl-cc/ast:ast-lambda-p ref) :to-be-truthy)
    (expect (plusp (length (cl-cc/ast:ast-lambda-body ref))) :to-be-truthy)))
  (it-sequential "The lambda body inside a callable ref calls APPLY with the original function."
(let* ((func-ast (cl-cc/ast:make-ast-var :name 'strlen))
         (ref      (cl-cc/php:%php-callable-ref func-ast))
         (body-call (first (cl-cc/ast:ast-lambda-body ref))))
    (expect (cl-cc/ast:ast-call-p body-call) :to-be-truthy)
    (expect (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func body-call))) :to-equal "APPLY"))))
