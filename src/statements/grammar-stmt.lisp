;;;; grammar-stmt.lisp — PHP CST Grammar: Statement Layer
;;;;
;;;; Contains statement-level CST parsers and the top-level entry point.
;;;; Expression-level parsers (php-cst-parse-primary through php-cst-parse-expr)
;;;; are in grammar.lisp (loads before).
;;;;
;;;; Load order: after grammar.lisp.

(in-package #:cl-cc/php/statements)

;;; ─── Statement Parsers ──────────────────────────────────────────────────────

(defun php-cst-parse-block (ts)
  "Parse { stmt* }. Returns list of CST nodes."
  (php-ts-expect ts :T-LBRACE nil "block")
  (let ((stmts nil))
    (loop
      (php-ts-skip-semis ts)
      (when (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE))
        (return))
      (let ((stmt (php-cst-parse-statement ts)))
        (when stmt (push stmt stmts))))
    (php-ts-expect ts :T-RBRACE nil "block")
    (nreverse stmts)))

;;; ─── Named keyword-statement parsers ───────────────────────────────────────

(defun %parse-php-echo-stmt (ts)
  (let ((kw-tok (php-ts-advance ts))
        (expr (php-cst-parse-expr ts)))
    (php-ts-skip-semis ts)
    (%php-cst-interior :echo (list (%php-tok-to-cst kw-tok) expr))))

(defun %parse-php-return-stmt (ts)
  (let ((kw-tok (php-ts-advance ts)))
    (if (php-ts-at-type-p ts :T-SEMI)
        (progn (php-ts-skip-semis ts)
               (%php-cst-interior :return (list (%php-tok-to-cst kw-tok))))
        (let ((expr (php-cst-parse-expr ts)))
          (php-ts-skip-semis ts)
          (%php-cst-interior :return (list (%php-tok-to-cst kw-tok) expr))))))

(defun %parse-php-if-stmt (ts)
  (let* ((kw-tok     (prog1 (php-ts-advance ts) (php-ts-expect ts :T-LPAREN nil "if condition")))
          (cond-expr  (prog1 (php-cst-parse-expr ts)
                             (php-ts-expect ts :T-RPAREN nil "if condition")))
          (then-stmts (%php-cst-parse-stmt-body ts))
          (elseif-stmts nil)
          (else-stmts nil))
    (loop while (%php-cst-keyword-p ts :elseif)
          do (let* ((elseif-tok (prog1 (php-ts-advance ts)
                                  (php-ts-expect ts :T-LPAREN nil "elseif condition")))
                    (elseif-cond (prog1 (php-cst-parse-expr ts)
                                   (php-ts-expect ts :T-RPAREN nil "elseif condition")))
                    (elseif-body (%php-cst-parse-stmt-body ts)))
               (push (%php-cst-interior :elseif
                                        (list (%php-tok-to-cst elseif-tok)
                                              elseif-cond
                                              (%php-cst-interior :then elseif-body)))
                     elseif-stmts)))
    (when (%php-cst-keyword-p ts :else)
      (php-ts-advance ts)
      (setf else-stmts (%php-cst-parse-stmt-body ts)))
    (%php-cst-interior :if
                        (append (list (%php-tok-to-cst kw-tok) cond-expr)
                                 (list (%php-cst-interior :then then-stmts))
                                (nreverse elseif-stmts)
                                (when else-stmts
                                  (list (%php-cst-interior :else else-stmts)))))))

(defun %parse-php-while-stmt (ts)
  (let* ((kw-tok     (prog1 (php-ts-advance ts) (php-ts-expect ts :T-LPAREN nil "while condition")))
         (cond-expr  (prog1 (php-cst-parse-expr ts)
                            (php-ts-expect ts :T-RPAREN nil "while condition")))
         (body-stmts (php-cst-parse-block ts)))
    (%php-cst-interior :while (list (%php-tok-to-cst kw-tok) cond-expr
                                    (%php-cst-interior :body body-stmts)))))

(defun %parse-php-for-stmt (ts)
  (let* ((kw-tok     (prog1 (php-ts-advance ts)     (php-ts-expect ts :T-LPAREN nil "for")))
         (init       (prog1 (php-cst-parse-expr ts)  (php-ts-expect ts :T-SEMI   nil "for")))
         (cond-expr  (prog1 (php-cst-parse-expr ts)  (php-ts-expect ts :T-SEMI   nil "for")))
         (incr       (prog1 (php-cst-parse-expr ts)  (php-ts-expect ts :T-RPAREN nil "for")))
         (body-stmts (php-cst-parse-block ts)))
    (%php-cst-interior :for (list (%php-tok-to-cst kw-tok) init cond-expr incr
                                  (%php-cst-interior :body body-stmts)))))

(defun %parse-php-foreach-stmt (ts)
  (let* ((kw-tok   (prog1 (php-ts-advance ts) (php-ts-expect ts :T-LPAREN nil "foreach")))
         (arr-expr (prog1 (php-cst-parse-expr ts) (php-ts-expect ts :T-KEYWORD :as "foreach")))
         (var-tok  (php-ts-expect ts :T-VAR nil "foreach")))
    (when (and (php-ts-at-type-p ts :T-OP)
               (equal "=>" (php-ts-peek-value ts)))
      (php-ts-advance ts)
      (setf var-tok (php-ts-expect ts :T-VAR nil "foreach value")))
    (php-ts-expect ts :T-RPAREN nil "foreach")
    (let ((body-stmts (php-cst-parse-block ts)))
      (%php-cst-interior :foreach
                         (list (%php-tok-to-cst kw-tok) arr-expr
                               (when var-tok (%php-tok-to-cst var-tok))
                               (%php-cst-interior :body body-stmts))))))

(defun %parse-php-break-stmt (ts)
  (let ((tok (php-ts-advance ts)))
    (php-ts-skip-semis ts)
    (%php-cst-interior :break (list (%php-tok-to-cst tok)))))

(defun %parse-php-continue-stmt (ts)
  (let ((tok (php-ts-advance ts))
        (expr nil))
    (unless (php-ts-at-type-p ts :T-SEMI)
      (setf expr (php-cst-parse-expr ts)))
    (php-ts-skip-semis ts)
    (%php-cst-interior :continue
                       (append (list (%php-tok-to-cst tok))
                               (when expr (list expr))))))

(defun %parse-php-try-catch-stmt (ts)
  (let ((kw-tok (php-ts-advance ts)))
    (let ((try-body (php-cst-parse-block ts))
          (catches nil)
          (finally-body nil))
      (loop while (and (not (php-ts-at-end-p ts))
                       (php-ts-at-type-p ts :T-KEYWORD)
                       (php-ts-at-value-p ts :catch))
            do (php-ts-advance ts)
               (php-ts-expect ts :T-LPAREN nil "catch")
               (let ((type-tok (php-ts-expect ts :T-IDENT nil "catch type"))
                     (var-tok  (php-ts-expect ts :T-VAR  nil "catch variable")))
                 (php-ts-expect ts :T-RPAREN nil "catch")
                 (let ((catch-body (php-cst-parse-block ts)))
                    (push (%php-cst-interior :catch
                            (append (when type-tok (list (%php-tok-to-cst type-tok)))
                                    (when var-tok  (list (%php-tok-to-cst var-tok)))
                                    catch-body))
                          catches))))
      (when (and (not (php-ts-at-end-p ts))
                 (php-ts-at-type-p ts :T-KEYWORD)
                 (php-ts-at-value-p ts :finally))
        (php-ts-advance ts)
        (setf finally-body (php-cst-parse-block ts)))
      (%php-cst-interior :try-catch
                          (append (list (%php-tok-to-cst kw-tok))
                                  (list (%php-cst-interior :try-body try-body))
                                  (nreverse catches)
                                  (when finally-body
                                    (list (%php-cst-interior :finally finally-body))))))))

(defun %php-cst-keyword-p (ts keyword)
  (and (not (php-ts-at-end-p ts))
       (php-ts-at-type-p ts :T-KEYWORD)
       (php-ts-at-value-p ts keyword)))

(defun %php-cst-parse-stmt-body (ts)
  (if (php-ts-at-type-p ts :T-LBRACE)
      (php-cst-parse-block ts)
      (let ((stmt (php-cst-parse-statement ts)))
        (if stmt (list stmt) nil))))

(defun %php-cst-skip-to-stmt-end (ts)
  (let ((items nil) (depth 0))
    (loop while (and (not (php-ts-at-end-p ts))
                     (or (> depth 0)
                         (not (member (php-ts-peek-type ts) '(:T-SEMI :T-RBRACE)))))
          do (let ((tok (php-ts-advance ts)))
               (when (member (php-tok-type tok) '(:T-LPAREN :T-LBRACE :T-LBRACKET)) (incf depth))
               (when (member (php-tok-type tok) '(:T-RPAREN :T-RBRACE :T-RBRACKET)) (decf depth))
               (push (%php-tok-to-cst tok) items)))
    (php-ts-skip-semis ts)
    (nreverse items)))

(defun %parse-php-do-while-stmt (ts)
  (let ((kw-tok (php-ts-advance ts)))
    (let ((body (%php-cst-parse-stmt-body ts)))
      (php-ts-expect ts :T-KEYWORD :while "do-while")
      (php-ts-expect ts :T-LPAREN nil "do-while")
      (let ((cond-expr (php-cst-parse-expr ts)))
        (php-ts-expect ts :T-RPAREN nil "do-while")
        (php-ts-skip-semis ts)
        (%php-cst-interior :do-while
                           (list (%php-tok-to-cst kw-tok) cond-expr
                                 (%php-cst-interior :body body)))))))

(defun %parse-php-switch-stmt (ts)
  (let* ((kw-tok (prog1 (php-ts-advance ts) (php-ts-expect ts :T-LPAREN nil "switch")))
         (expr (prog1 (php-cst-parse-expr ts) (php-ts-expect ts :T-RPAREN nil "switch")))
         (sections nil))
    (php-ts-expect ts :T-LBRACE nil "switch")
    (loop
      (php-ts-skip-semis ts)
      (when (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE)) (return))
      (cond
        ((%php-cst-keyword-p ts :case)
         (let ((case-tok (php-ts-advance ts))
               (case-expr (php-cst-parse-expr ts))
               (body nil))
           (when (php-ts-at-type-p ts :T-COLON) (php-ts-advance ts))
           (loop until (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE)
                           (%php-cst-keyword-p ts :case) (%php-cst-keyword-p ts :default))
                 do (let ((stmt (php-cst-parse-statement ts)))
                      (when stmt (push stmt body))))
           (push (%php-cst-interior :case
                                    (list (%php-tok-to-cst case-tok) case-expr
                                          (%php-cst-interior :body (nreverse body))))
                 sections)))
        ((%php-cst-keyword-p ts :default)
         (let ((default-tok (php-ts-advance ts)) (body nil))
           (when (php-ts-at-type-p ts :T-COLON) (php-ts-advance ts))
           (loop until (or (php-ts-at-end-p ts) (php-ts-at-type-p ts :T-RBRACE)
                           (%php-cst-keyword-p ts :case))
                 do (let ((stmt (php-cst-parse-statement ts)))
                      (when stmt (push stmt body))))
           (push (%php-cst-interior :default
                                    (list (%php-tok-to-cst default-tok)
                                          (%php-cst-interior :body (nreverse body))))
                 sections)))
        (t (%php-cst-skip-to-stmt-end ts))))
    (php-ts-expect ts :T-RBRACE nil "switch")
    (%php-cst-interior :switch
                       (list (%php-tok-to-cst kw-tok) expr
                             (%php-cst-interior :sections (nreverse sections))))))

(defun %parse-php-include-like-stmt (ts)
  (let* ((tok (php-ts-advance ts))
         (expr (php-cst-parse-expr ts)))
    (php-ts-skip-semis ts)
    (%php-cst-interior :include-like (list (%php-tok-to-cst tok) expr))))

(defun %parse-php-noop-keyword-stmt (ts)
  (let ((tok (php-ts-advance ts))
        (items (%php-cst-skip-to-stmt-end ts)))
    (%php-cst-interior :noop (cons (%php-tok-to-cst tok) items))))

(defun %parse-php-goto-stmt (ts)
  (let ((tok (php-ts-advance ts))
        (label (php-ts-expect ts :T-IDENT nil "goto")))
    (php-ts-skip-semis ts)
    (%php-cst-interior :goto (append (list (%php-tok-to-cst tok))
                                     (when label (list (%php-tok-to-cst label)))))))

(defun %parse-php-label-stmt (ts)
  (let ((label (php-ts-advance ts)))
    (php-ts-expect ts :T-COLON nil "label")
    (%php-cst-interior :label (list (%php-tok-to-cst label)))))

(defun %parse-php-expr-stmt (ts)
  (let ((expr (php-cst-parse-expr ts)))
    (php-ts-skip-semis ts)
    expr))

;;; ─── Keyword → parser dispatch table ───────────────────────────────────────

(eval-when (:load-toplevel :execute) (register-php-cst-keyword-statement-parser :echo #'%parse-php-echo-stmt) (register-php-cst-keyword-statement-parser :return #'%parse-php-return-stmt) (register-php-cst-keyword-statement-parser :if #'%parse-php-if-stmt) (register-php-cst-keyword-statement-parser :while #'%parse-php-while-stmt) (register-php-cst-keyword-statement-parser :for #'%parse-php-for-stmt) (register-php-cst-keyword-statement-parser :foreach #'%parse-php-foreach-stmt) (register-php-cst-keyword-statement-parser :do #'%parse-php-do-while-stmt) (register-php-cst-keyword-statement-parser :switch #'%parse-php-switch-stmt) (register-php-cst-keyword-statement-parser :break #'%parse-php-break-stmt) (register-php-cst-keyword-statement-parser :continue #'%parse-php-continue-stmt) (register-php-cst-keyword-statement-parser :try #'%parse-php-try-catch-stmt) (register-php-cst-keyword-statement-parser :include #'%parse-php-include-like-stmt) (register-php-cst-keyword-statement-parser :require #'%parse-php-include-like-stmt) (register-php-cst-keyword-statement-parser :include-once #'%parse-php-include-like-stmt) (register-php-cst-keyword-statement-parser :require-once #'%parse-php-include-like-stmt) (register-php-cst-keyword-statement-parser :declare #'%parse-php-noop-keyword-stmt) (register-php-cst-keyword-statement-parser :goto #'%parse-php-goto-stmt) (register-php-cst-keyword-statement-parser :namespace #'%parse-php-noop-keyword-stmt) (register-php-cst-keyword-statement-parser :use #'%parse-php-noop-keyword-stmt))

(defun php-cst-parse-statement (ts)
  "Parse a single PHP statement, dispatching on keyword via *php-keyword-statement-parsers*."
  (cond
    ((php-ts-at-type-p ts :T-KEYWORD)
     (let* ((value  (php-ts-peek-value ts))
            (parser (gethash value *php-keyword-statement-parsers*)))
       (if parser (funcall parser ts) (%parse-php-expr-stmt ts))))
    ((and (php-ts-at-type-p ts :T-IDENT)
          (let ((next (second (php-token-stream-tokens ts))))
            (and next (eq (php-tok-type next) :T-COLON))))
     (%parse-php-label-stmt ts))
    ((and (php-ts-at-type-p ts :T-IDENT)
          (%php-include-keyword-value (php-ts-peek-value ts)))
     (let ((parser (gethash (%php-include-keyword-value (php-ts-peek-value ts)) *php-keyword-statement-parsers*)))
       (if parser (funcall parser ts) (%parse-php-expr-stmt ts))))
    (t (%parse-php-expr-stmt ts))))
(eval-when (:load-toplevel :execute)
  (register-php-cst-statement-parser (function php-cst-parse-statement)))

;;; ─── Top-Level Entry Point ──────────────────────────────────────────────────

