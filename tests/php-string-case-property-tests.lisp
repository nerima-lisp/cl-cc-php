(in-package :cl-cc-php/test)

;;; Property-based tests (cl-weave IT-PROPERTY + GEN-STRING) for the PHP case
;;; conversion builtins — chosen over more it-sequential example cases because
;;; the properties below hold for EVERY input, not just a few hand-picked ones,
;;; so a generator-driven check catches edge cases example-based tests miss.
(describe "PHP string case-conversion properties"

(it-property "%php-strtolower is idempotent"
    ((s (gen-string :alphabet "AaBbCcXxYyZz0123 -_")))
  (string= (%php-strtolower (%php-strtolower s))
           (%php-strtolower s)))

(it-property "%php-strtoupper is idempotent"
    ((s (gen-string :alphabet "AaBbCcXxYyZz0123 -_")))
  (string= (%php-strtoupper (%php-strtoupper s))
           (%php-strtoupper s)))

(it-property "%php-strtolower and %php-strtoupper preserve string length"
    ((s (gen-string :alphabet "AaBbCcXxYyZz0123 -_")))
  (and (= (length s) (length (%php-strtolower s)))
       (= (length s) (length (%php-strtoupper s)))))

(it-property "lowercasing then uppercasing loses no non-alphabetic characters"
    ((s (gen-string :alphabet "AaBbCcXxYyZz0123 -_")))
  ;; Digits/space/hyphen/underscore are case-invariant, so they survive any
  ;; combination of the two conversions unchanged in position and identity.
  (let ((round-tripped (%php-strtoupper (%php-strtolower s))))
    (loop for c across s
          for r across round-tripped
          always (or (alpha-char-p c) (char= c r)))))

  )
