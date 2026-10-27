(in-package #:cl-cc/php/strings)

(defun %php-strlen (s)
  "Return the length of string S."
  (check-type s string)
  (length s))

(defun %php-strtolower (s)
  "Return S converted to lowercase."
  (check-type s string)
  (string-downcase s))

(defun %php-strtoupper (s)
  "Return S converted to uppercase."
  (check-type s string)
  (string-upcase s))
