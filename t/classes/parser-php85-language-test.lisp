(in-package :cl-cc/php/classes/test)

(describe "PHP class parser tests"
  (it-sequential
    "PHP 8.5 #[Override] is accepted on inherited methods."
    (expect
      (cl-cc/ast:ast-defclass-p
        (%php-first
          "<?php class Base { public function label(): string { return 'x'; } } class Child extends Base { #[Override] public function label(): string { return 'y'; } }"))
      :to-be-truthy))
  (it-sequential
    "PHP 8.5 #[Override] is accepted on inherited properties."
    (expect
      (cl-cc/ast:ast-defclass-p
        (%php-first
          "<?php class Base { public string $name; } class Child extends Base { #[Override] public string $name; }"))
      :to-be-truthy))
  (it-sequential
    "PHP 8.5 #[Override] does not accept private inherited properties."
    (signals
      error
      (cl-cc/php:parse-php-source
        "<?php class Base { private string $name; } class Child extends Base { #[Override] public string $name; }"))))
