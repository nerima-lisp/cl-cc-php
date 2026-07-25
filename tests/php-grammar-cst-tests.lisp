;;;; tests/php-grammar-cst-tests.lisp — PHP grammar CST expression-parser tests
(in-package :cl-cc-php/test)

(defun %php-cst-ts (php-source)
  "Tokenize PHP-SOURCE (a full \"<?php ...\" snippet) and wrap it in a
php-token-stream, ready for the php-cst-parse-* functions."
  (cl-cc/php::make-php-token-stream
   :tokens (cl-cc/php:tokenize-php-source php-source)
   :source php-source
   :diagnostics nil))

(describe "PHP grammar CST expression parsers"

(it-sequential "parses primary literals: int, float, string, variable"
  (expect (cl-cc/parse:cst-node-kind
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php 42")))
          :to-be :T-INT)
  (expect (cl-cc/parse:cst-node-kind
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php 4.2")))
          :to-be :T-FLOAT)
  (expect (cl-cc/parse:cst-node-kind
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php \"hi\"")))
          :to-be :T-STRING)
  (expect (cl-cc/parse:cst-node-kind
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php $x")))
          :to-be :T-VAR))

(it-sequential "parses true/false/null keyword literals"
  (expect (cl-cc/parse:cst-token-value
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php true")))
          :to-be :true)
  (expect (cl-cc/parse:cst-token-value
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php false")))
          :to-be :false)
  (expect (cl-cc/parse:cst-token-value
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php null")))
          :to-be :null))

(it-sequential "parses a parenthesized expression by returning the inner CST"
  (expect (cl-cc/parse:cst-node-kind
           (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php (42)")))
          :to-be :T-INT))

(it-sequential "parses a bare identifier call as a :call interior node"
  (let ((cst (cl-cc/php::php-cst-parse-primary (%php-cst-ts "<?php strlen(\"x\")"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :call)
    (expect (length (cl-cc/parse:cst-interior-children cst)) :to-equal 2)))

(it-sequential "parses new ClassName(args) as a :new interior node"
  (let ((cst (cl-cc/php::php-cst-parse-new (%php-cst-ts "<?php new Foo(1, 2)"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :new)
    ;; new-keyword token + class-name token + 2 arg CSTs
    (expect (length (cl-cc/parse:cst-interior-children cst)) :to-equal 4)))

(it-sequential "parses new ClassName with no arglist at all"
  (let ((cst (cl-cc/php::php-cst-parse-new (%php-cst-ts "<?php new Foo"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :new)
    (expect (length (cl-cc/parse:cst-interior-children cst)) :to-equal 2)))

(it-sequential "parses an empty arglist as no CST nodes"
  (let ((ts (%php-cst-ts "<?php ()")))
    (expect (cl-cc/php::php-cst-parse-arglist ts) :to-be nil)))

(it-sequential "parses a multi-argument arglist"
  (let ((ts (%php-cst-ts "<?php (1, 2, 3)")))
    (expect (length (cl-cc/php::php-cst-parse-arglist ts)) :to-equal 3)))

(it-sequential "parses -> property access as :property-access"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $obj->prop"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :property-access)))

(it-sequential "parses ->method() as :method-call"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $obj->method(1)"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :method-call)))

(it-sequential "parses ?-> nullsafe property access as :nullsafe-access"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $obj?->prop"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :nullsafe-access)))

(it-sequential "parses ?->method() as :nullsafe-method-call"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $obj?->method()"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :nullsafe-method-call)))

(it-sequential "parses [index] array access as :array-access"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $arr[0]"))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :array-access)))

(it-sequential "chains multiple postfix operations left-to-right"
  (let ((cst (cl-cc/php::php-cst-parse-postfix (%php-cst-ts "<?php $obj->a->b"))))
    ;; the outer node is the SECOND -> access; its first child is the
    ;; property-access CST for $obj->a
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :property-access)
    (expect (cl-cc/parse:cst-node-kind (first (cl-cc/parse:cst-interior-children cst)))
            :to-be :property-access)))

(it-sequential-each
    (("<?php !$x" "!")
     ("<?php -$x" "-")
     ("<?php +$x" "+"))
    "parses unary ~S as a :unary-op interior node"
    (source op)
  (let ((cst (cl-cc/php::php-cst-parse-unary (%php-cst-ts source))))
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :unary-op)
    (expect (cl-cc/parse:cst-token-value (first (cl-cc/parse:cst-interior-children cst)))
            :to-equal op)))

(it-sequential "unary parsing falls through to postfix when there is no unary operator"
  (expect (cl-cc/parse:cst-node-kind (cl-cc/php::php-cst-parse-unary (%php-cst-ts "<?php 42")))
          :to-be :T-INT))

(it-sequential-each
    (("<?php 2 * 3" :binary-op)
     ("<?php 2 + 3" :binary-op)
     ("<?php 2 . 3" :binary-op)
     ("<?php 1 |> strval(...)" :pipe-op)
     ("<?php 1 == 2" :binary-op)
     ("<?php $a && $b" :binary-op)
     ("<?php $a || $b" :binary-op))
    "parses ~S through the full precedence chain into a ~S node"
    (source expected-kind)
  (expect (cl-cc/parse:cst-node-kind (cl-cc/php::php-cst-parse-or (%php-cst-ts source)))
          :to-be expected-kind))

(it-sequential "left-associates a chain of same-precedence operators"
  (let ((cst (cl-cc/php::php-cst-parse-add (%php-cst-ts "<?php 1 + 2 + 3"))))
    ;; (1 + 2) + 3 — the outer node's LHS child is itself a :binary-op
    (expect (cl-cc/parse:cst-node-kind cst) :to-be :binary-op)
    (expect (cl-cc/parse:cst-node-kind (second (cl-cc/parse:cst-interior-children cst)))
            :to-be :binary-op)))

(it-sequential "an expression with no matching operator falls through unchanged"
  (expect (cl-cc/parse:cst-node-kind (cl-cc/php::php-cst-parse-mul (%php-cst-ts "<?php 42")))
          :to-be :T-INT))

  )
