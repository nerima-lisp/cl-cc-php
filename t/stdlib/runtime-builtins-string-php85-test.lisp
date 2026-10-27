(in-package :cl-cc/php/stdlib/test)

(describe "PHP string tests"
  (it-sequential
    "The grapheme cluster helper keeps base characters and combining marks together."
    (let* ((cluster (format nil "a~C" (code-char #x0301)))
           (clusters (cl-cc/php/stdlib::%php-grapheme-clusters cluster)))
      (expect (= 1 (length clusters)) :to-be-truthy)
      (expect (aref clusters 0) :to-equal cluster)))
  (it-sequential
    "The similar_text helper counts common character matches."
    (expect (= 2 (cl-cc/php/stdlib::%php-similar-text "abc" "axc")) :to-be-truthy))
  (it-sequential
    "The soundex helper returns the expected four-character code."
    (expect (cl-cc/php/stdlib::%php-soundex "Example") :to-equal "E251")))
