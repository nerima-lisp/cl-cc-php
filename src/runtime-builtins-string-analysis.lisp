;;;; runtime-builtins-string-analysis.lisp -- Search, word, phonetic, and output PHP string
;;;; operations

(in-package :cl-cc/php)

;;; ─── String search ────────────────────────────────────────────────────────────

(defun %php-strstr (haystack needle &optional before-needle)
  "PHP strstr: find first occurrence of NEEDLE in HAYSTACK."
  (let* ((h (%php-stringify haystack))
         (n (%php-stringify needle))
         (pos (search n h)))
    (when pos
      (if (%php-truthy before-needle)
          (subseq h 0 pos)
          (subseq h pos)))))

(defun %php-stristr (haystack needle &optional before-needle)
  "PHP stristr: case-insensitive strstr."
  (let* ((h (%php-stringify haystack))
         (n (%php-stringify needle))
         (pos (search (string-downcase n) (string-downcase h))))
    (when pos
      (if (%php-truthy before-needle)
          (subseq h 0 pos)
          (subseq h pos)))))

(defun %php-strchr (haystack needle &optional before-needle)
  "PHP strchr: alias for strstr."
  (%php-strstr haystack needle before-needle))

;;; ─── String word operations ───────────────────────────────────────────────────

(defun %php-str-word-count (string &optional (format 0) charlist)
  "PHP str_word_count: count words or return word array."
  (declare (ignore charlist))
  (let* ((s (%php-stringify string))
         (words nil)
         (in-word nil)
         (word-start 0))
    (loop for i from 0 below (length s)
          for ch = (char s i)
          do (cond ((and (alpha-char-p ch) (not in-word))
                    (setf in-word t word-start i))
                   ((and (not (alpha-char-p ch)) in-word)
                    (push (cons word-start (subseq s word-start i)) words)
                    (setf in-word nil)))
          finally (when in-word
                    (push (cons word-start (subseq s word-start)) words)))
    (let ((ordered (reverse words)))
      (cond ((= format 0) (length ordered))
            ((= format 1) (let ((r (%php-make-array)))
                            (loop for i from 0 for (pos . w) in ordered
                                  do (%php-array-set r i w))
                            r))
            ((= format 2) (let ((r (%php-make-array)))
                            (loop for (pos . w) in ordered
                                  do (%php-array-set r pos w))
                            r))
            (t (length ordered))))))

;;; ─── Edit distance / similarity ──────────────────────────────────────────────

(defun %php-edit-distance (a b)
  "Return the Levenshtein distance between two sequences A and B."
  (let* ((m (length a))
         (n (length b))
         (dp (make-array (list (1+ m) (1+ n)) :initial-element 0)))
    (dotimes (i (1+ m)) (setf (aref dp i 0) i))
    (dotimes (j (1+ n)) (setf (aref dp 0 j) j))
    (loop for i from 1 to m do
      (loop for j from 1 to n do
        (setf (aref dp i j)
              (if (equal (elt a (1- i)) (elt b (1- j)))
                  (aref dp (1- i) (1- j))
                  (1+ (min (aref dp (1- i) j)
                           (aref dp i (1- j))
                           (aref dp (1- i) (1- j))))))))
    (aref dp m n)))

(defun %php-levenshtein (s1 s2)
  "PHP levenshtein: edit distance between S1 and S2."
  (%php-edit-distance (%php-stringify s1) (%php-stringify s2)))

(defun %php-combining-mark-p (ch)
  "Return true when CH is in a common Unicode combining mark block."
  (let ((code (char-code ch)))
    (or (<= #x0300 code #x036F)
        (<= #x1AB0 code #x1AFF)
        (<= #x1DC0 code #x1DFF)
        (<= #x20D0 code #x20FF)
        (<= #xFE20 code #xFE2F))))

(defun %php-grapheme-clusters (string)
  "Split STRING into pragmatic Unicode grapheme clusters for Intl helpers."
  (let ((clusters nil)
        (current nil))
    (labels ((flush-current ()
               (when current
                 (push (coerce (nreverse current) 'string) clusters)
                 (setf current nil))))
      (loop for ch across (%php-stringify string) do
        (if (and current (%php-combining-mark-p ch))
            (push ch current)
            (progn
              (flush-current)
              (setf current (list ch)))))
      (flush-current))
    (coerce (nreverse clusters) 'vector)))

(defun %php-grapheme-levenshtein (s1 s2)
  "PHP 8.5 grapheme_levenshtein: edit distance by grapheme clusters."
  (%php-edit-distance (%php-grapheme-clusters s1)
                      (%php-grapheme-clusters s2)))

(defun %php-similar-text-lcs (s1 s2)
  "Return (values pos1 pos2 length) of the first-found longest common
substring of S1 and S2 — PHP's own algorithm scans (i, j) in that order and
keeps the first match of the longest length it finds, not just any longest
match, so a different scan order can return a different, still-correct-length
answer for a tied input."
  (let ((best-len 0) (best-i 0) (best-j 0))
    (loop for i from 0 below (length s1) do
      (loop for j from 0 below (length s2) do
        (let ((k 0))
          (loop while (and (< (+ i k) (length s1))
                           (< (+ j k) (length s2))
                           (char= (char s1 (+ i k)) (char s2 (+ j k))))
                do (incf k))
          (when (> k best-len)
            (setf best-len k best-i i best-j j)))))
    (values best-i best-j best-len)))

(defun %php-similar-text-count (s1 s2)
  "Recursive char count PHP's similar_text is built on: the longest common
substring's length, plus the same count recursed over the parts of S1/S2
before and after that match."
  (if (or (zerop (length s1)) (zerop (length s2)))
      0
      (multiple-value-bind (pos1 pos2 len) (%php-similar-text-lcs s1 s2)
        (if (zerop len)
            0
            (+ len
               (%php-similar-text-count (subseq s1 0 pos1) (subseq s2 0 pos2))
               (%php-similar-text-count (subseq s1 (+ pos1 len)) (subseq s2 (+ pos2 len))))))))

(defun %php-similar-text (s1 s2 &optional percent-var)
  "PHP similar_text: compute similarity between S1 and S2 via PHP's own
longest-common-substring recursion (%PHP-SIMILAR-TEXT-COUNT above) — not a
naive greedy per-character scan, which silently overcounts for many inputs
(e.g. it returned 2, not PHP's real 1, for (\"ab\", \"ba\")). PERCENT-VAR, if a
PHP reference, receives the percentage PHP defines as
common*2/(len1+len2)*100."
  (let* ((a (%php-stringify s1))
         (b (%php-stringify s2))
         (common (%php-similar-text-count a b)))
    (when (%php-ref-p percent-var)
      (%php-ref-set! percent-var
                     (let ((total (+ (length a) (length b))))
                       (if (zerop total)
                           0.0d0
                           (/ (* common 2.0d0 100) total)))))
    common))

(defun %php-soundex (string)
  "PHP soundex: Soundex phonetic encoding of STRING."
  (let* ((s (string-upcase (%php-stringify string)))
         (table '((#\B . #\1) (#\F . #\1) (#\P . #\1) (#\V . #\1)
                  (#\C . #\2) (#\G . #\2) (#\J . #\2) (#\K . #\2)
                  (#\Q . #\2) (#\S . #\2) (#\X . #\2) (#\Z . #\2)
                  (#\D . #\3) (#\T . #\3)
                  (#\L . #\4)
                  (#\M . #\5) (#\N . #\5)
                  (#\R . #\6))))
    (if (= (length s) 0) ""
        (let ((result (make-array 4 :element-type 'character :initial-element #\0))
              (idx 1)
              (prev #\Nul))
          (setf (aref result 0) (char s 0))
          (loop for ch across (subseq s 1)
                while (< idx 4)
                do (let ((code (cdr (assoc ch table))))
                     (when (and code (not (eql code prev)))
                       (setf (aref result idx) code
                             prev code)
                       (incf idx))))
          (coerce result 'string)))))

;;; ─── printf family ────────────────────────────────────────────────────────────

(defun %php-printf (format-string &rest args)
  "PHP printf: formatted print, returns length written."
  (let ((out (apply #'%php-sprintf format-string args)))
    (write-string out)
    (length out)))

(defun %php-vsprintf (format-string args-array)
  "PHP vsprintf: sprintf with args from array."
  (apply #'%php-sprintf format-string (%php-array-values-list args-array)))

(defun %php-vprintf (format-string args-array)
  "PHP vprintf: printf with args from array."
  (let ((out (%php-vsprintf format-string args-array)))
    (write-string out)
    (length out)))
