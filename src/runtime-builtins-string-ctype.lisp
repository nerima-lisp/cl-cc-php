;;;; packages/php/src/runtime-builtins-string-ctype.lisp -- ctype PHP string predicates

(in-package :cl-cc/php)

;;; ─── ctype_* character classification (PHP ext/ctype) ────────────────────────

(defmacro define-php-ctype-predicate (name docstring predicate)
  "Define PHP ctype_* predicate NAME: true when TEXT (stringified) is non-empty
and every character satisfies PREDICATE."
  `(defun ,name (text)
     ,docstring
     (let ((s (%php-stringify text)))
       (and (> (length s) 0)
            (every ,predicate s)))))

(define-php-ctype-predicate %php-ctype-alpha
    "PHP ctype_alpha: check if all chars are alphabetic."
  #'alpha-char-p)

(define-php-ctype-predicate %php-ctype-digit
    "PHP ctype_digit: check if all chars are decimal digits."
  #'digit-char-p)

(define-php-ctype-predicate %php-ctype-alnum
    "PHP ctype_alnum: check if all chars are alphanumeric."
  #'alphanumericp)

(define-php-ctype-predicate %php-ctype-space
    "PHP ctype_space: check if all chars are whitespace."
  (lambda (c) (member c '(#\Space #\Tab #\Newline #\Return #\Page #\Null))))

(define-php-ctype-predicate %php-ctype-upper
    "PHP ctype_upper: check if all chars are uppercase."
  (lambda (c) (and (alpha-char-p c) (upper-case-p c))))

(define-php-ctype-predicate %php-ctype-lower
    "PHP ctype_lower: check if all chars are lowercase."
  (lambda (c) (and (alpha-char-p c) (lower-case-p c))))

(define-php-ctype-predicate %php-ctype-punct
    "PHP ctype_punct: check if all chars are punctuation (visible non-alphanumeric)."
  (lambda (c) (and (graphic-char-p c) (not (alphanumericp c)) (not (char= c #\Space)))))

(define-php-ctype-predicate %php-ctype-graph
    "PHP ctype_graph: check if all chars are visible (non-space graphic)."
  (lambda (c) (and (graphic-char-p c) (not (char= c #\Space)))))

(define-php-ctype-predicate %php-ctype-print
    "PHP ctype_print: check if all chars are printable (including space)."
  #'graphic-char-p)

(define-php-ctype-predicate %php-ctype-xdigit
    "PHP ctype_xdigit: check if all chars are valid hexadecimal."
  (lambda (c) (digit-char-p c 16)))
