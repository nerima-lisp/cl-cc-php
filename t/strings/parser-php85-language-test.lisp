(in-package :cl-cc/php/strings/test)

(describe "PHP string tests"
  (it-sequential
    "grapheme_levenshtein() treats a base character plus combining mark as one cluster."
    (let ((cluster (format nil "a~C" (code-char #x0301))))
      (expect (= 1 (cl-cc/php:%php-grapheme-levenshtein cluster "")) :to-be-truthy))))
