;;;; parser-stmt-params.lisp — PHP Parser: type annotation and parameter-list parsing

(in-package #:cl-cc/php/types)

(defun %php-type-keyword-token-p (stream)
  "Return true when STREAM starts with a keyword valid in PHP type position."
  (and stream
       (eq (php-peek-type stream) :T-KEYWORD)
       (member (php-peek-value stream) '(:array :null :true :false) :test #'eq)))

(defun %php-type-atom-token-p (stream)
  "Return true when STREAM starts with a PHP type atom."
  (and stream
       (or (eq (php-peek-type stream) :T-TYPE)
           (eq (php-peek-type stream) :T-IDENT)
           (%php-type-keyword-token-p stream))))

(defun %php-type-token-string (token)
  "Return TOKEN's PHP spelling for metadata storage."
  (let ((value (php-tok-value token)))
    (string-downcase
     (etypecase value
       (keyword (symbol-name value))
       (symbol (symbol-name value))
       (string value)))))

(defun %php-parse-parenthesized-type (stream)
  "Parse a parenthesized PHP type group, used by PHP 8.2 DNF types."
  (let ((current (cdr stream))
        (parts nil))
    (multiple-value-bind (first-part rest) (%php-parse-type-term current)
      (unless first-part
        (return-from %php-parse-parenthesized-type (values nil stream)))
      (push first-part parts)
      (setf current rest))
    (loop while (and current
                     (eq (php-peek-type current) :T-OP)
                     (member (php-peek-value current) '("|" "&") :test #'equal))
          for op = (php-peek-value current)
          do (multiple-value-bind (part rest) (%php-parse-type-term (cdr current))
               (unless part
                 (return-from %php-parse-parenthesized-type (values nil stream)))
               (push op parts)
               (push part parts)
               (setf current rest)))
    (unless (eq (php-peek-type current) :T-RPAREN)
      (return-from %php-parse-parenthesized-type (values nil stream)))
    (values (format nil "(~A)" (apply #'concatenate 'string (nreverse parts)))
            (cdr current))))

(defun %php-parse-type-term (stream)
  "Parse one PHP type atom or parenthesized type group."
  (cond
    ((%php-type-atom-token-p stream)
     (values (%php-type-token-string (php-peek stream)) (cdr stream)))
    ((eq (php-peek-type stream) :T-LPAREN)
     (%php-parse-parenthesized-type stream))
    (t
     (values nil stream))))

(defun php-parse-type-annotation (stream)
  "Parse a PHP type annotation from STREAM.
Returns (values type-string remaining-stream). Handles nullable, union,
intersection, and PHP 8.2 DNF type syntax as metadata only."
  (let ((current stream)
        (parts nil))
    (when (eq (php-peek-type current) :T-NULLABLE)
      (push "?" parts)
      (setf current (cdr current)))
    (multiple-value-bind (first-part rest) (%php-parse-type-term current)
      (unless first-part
        (return-from php-parse-type-annotation (values nil stream)))
      (push first-part parts)
      (setf current rest))
    (loop while (and current
                     (eq (php-peek-type current) :T-OP)
                     (member (php-peek-value current) '("|" "&") :test #'equal)
                     (multiple-value-bind (part _rest)
                         (%php-parse-type-term (cdr current))
                       (declare (ignore _rest))
                       part))
          for op = (php-peek-value current)
          do (multiple-value-bind (part rest) (%php-parse-type-term (cdr current))
               (push op parts)
               (push part parts)
               (setf current rest)))
    (values (apply #'concatenate 'string (nreverse parts)) current)))

;;; ─── Intersection types (PHP 8.1) ───────────────────────────────────────────
;;;
;;; `function f(Iterator&Countable $c)`. php-parse-type-annotation above
;;; already walks `&` in its type loop; this builds the structured descriptor.

(defun %php-parse-intersection-type (first-type stream)
  "After FIRST-TYPE, consume any `& TypeName` continuations and build an
intersection type descriptor.
Returns (values type-spec rest-stream).
When no & follows, returns FIRST-TYPE and STREAM unchanged."
  (if (and stream
           (eq (php-peek-type stream) :T-OP)
           (string= (php-peek-value stream) "&")
           (cdr stream)
           (%php-type-atom-token-p (cdr stream)))
      (let ((parts (list first-type))
            (current (cdr stream)))       ; skip &
        (loop
          (unless (%php-type-atom-token-p current) (return))
          (let ((segment (%php-type-token-string (php-peek current))))
            (push segment parts)
            (setf current (cdr current)))
          (if (and (eq (php-peek-type current) :T-OP)
                   (string= (php-peek-value current) "&")
                   (cdr current)
                   (%php-type-atom-token-p (cdr current)))
              (setf current (cdr current))  ; skip & and continue
              (return)))
        (values (list* :intersection (nreverse parts)) current))
      (values first-type stream)))
