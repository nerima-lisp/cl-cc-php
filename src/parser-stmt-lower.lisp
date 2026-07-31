;;;; parser-stmt-lower.lisp — PHP Parser: compound-statement parsing and AST lowering

(in-package :cl-cc/php)

(defun %php-parse-if-tail (stream known-vars)
  "Parse the then/body plus elseif/else tail after an if condition."
  (multiple-value-bind (then-stmts rest kv) (%php-parse-statement-body stream known-vars)
    (let ((else-ast (make-ast-quote :value nil)))
      (cond
        ((%php-keyword-p rest :elseif)
         (multiple-value-bind (elseif-cond rest2 kv2) (%php-parse-paren-expr (cdr rest) kv)
           (multiple-value-bind (elseif-body rest3 kv3 elseif-else) (%php-parse-if-tail rest2 kv2)
             (setf else-ast (make-ast-if :cond elseif-cond
                                          :then (make-ast-progn :forms elseif-body)
                                          :else elseif-else)
                   rest rest3 kv kv3))))
        ((%php-keyword-p rest :else)
         (multiple-value-bind (else-stmts rest2 kv2) (%php-parse-statement-body (cdr rest) kv)
           (setf else-ast (make-ast-progn :forms else-stmts)
                 rest rest2 kv kv2))))
      (values then-stmts rest kv else-ast))))

(defun %php-parse-switch-body (stream known-vars break-tag)
  "Parse switch case/default sections."
  (let ((current (%php-consume-expected :T-LBRACE stream))
        (cases nil)
        (default-body nil)
        (warnings nil)
        (kv known-vars))
    (loop
      (setf current (php-skip-semis current))
      (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE))
        (return))
      (cond
        ((%php-keyword-p current :case)
         (multiple-value-bind (case-expr rest kv2) (php-parse-expr (cdr current) kv)
           (setf current (cond
                           ((eq (php-peek-type rest) :T-COLON) (cdr rest))
                           ((eq (php-peek-type rest) :T-SEMI)
                            (push (%php-switch-deprecation-warning-ast
                                   (concatenate
                                    'string
                                    "PHP 8.5 deprecates semicolons after switch case labels; "
                                    "use a colon instead"))
                                  warnings)
                            (cdr rest))
                           (t (php-skip-semis rest)))
                 kv kv2)
           (let ((body nil))
             (loop
               (setf current (php-skip-semis current))
               (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE)
                         (%php-keyword-p current :case) (%php-keyword-p current :default))
                 (return))
               (let ((*php-loop-break-target* break-tag))
                 (multiple-value-bind (stmt rest2 kv3) (php-parse-statement current kv)
                   (when stmt (push stmt body))
                   (setf current rest2 kv kv3))))
             (push (cons case-expr (nreverse body)) cases))))
        ((%php-keyword-p current :default)
         (setf current (cdr current))
         (cond
           ((eq (php-peek-type current) :T-COLON)
            (setf current (cdr current)))
           ((eq (php-peek-type current) :T-SEMI)
            (push (%php-switch-deprecation-warning-ast
                   "PHP 8.5 deprecates semicolons after switch default labels; use a colon instead")
                  warnings)
            (setf current (cdr current))))
         (let ((body nil))
           (loop
             (setf current (php-skip-semis current))
             (when (or (php-at-eof-p current) (eq (php-peek-type current) :T-RBRACE)
                       (%php-keyword-p current :case))
               (return))
             (let ((*php-loop-break-target* break-tag))
               (multiple-value-bind (stmt rest2 kv2) (php-parse-statement current kv)
                 (when stmt (push stmt body))
                 (setf current rest2 kv kv2))))
           (setf default-body (nreverse body))))
        (t (setf current (%php-skip-to-stmt-end current)))))
    (values (nreverse cases) default-body (%php-consume-expected :T-RBRACE current)
            kv (nreverse warnings))))

(defun %php-switch-deprecation-warning-ast (message)
  "Emit E_DEPRECATED for a PHP 8.5 switch-label deprecation."
  (make-ast-progn
   :forms (list (%php-call 'cl-cc/php::%php-trigger-error
                           (make-ast-quote :value message)
                           (make-ast-int :value 8192)))))

(defun %php-lower-while-with-label (cond-expr body-stmts loop-tag)
  "Lower a PHP while loop using LOOP-TAG as the continue target."
  (make-ast-block :name nil
    :body (list
           (%php-make-tagbody
            (append (list loop-tag
                          (make-ast-if
                           :cond cond-expr
                           :then (make-ast-quote :value nil)
                           :else (make-ast-return-from :name nil
                                                      :value (make-ast-quote :value nil))))
                    body-stmts
                    (list (make-ast-go :tag loop-tag))
                    (when *php-loop-break-target*
                      (list *php-loop-break-target*)))))))

(defun %php-lower-for-with-labels (cond-expr body-stmts incr continue-tag)
  "Lower a PHP for loop. CONTINUE-TAG (the loop's continue target) is placed
BEFORE the increment, so `continue' runs the increment and then re-tests the
condition — unlike a plain while, where continue jumps straight back to the test.
Collapsing for into while with the increment merely appended to the body would
make `continue' skip the increment and loop forever."
  (let ((top-tag (gensym "FOR-TOP-")))
    (make-ast-block :name nil
      :body (list
             (%php-make-tagbody
              ;; Flow is driven by explicit gos because the tagbody lowerer does
              ;; not fall through between tag sections. Normal end-of-body and an
              ;; explicit `continue' both jump to CONTINUE-TAG, which runs INCR and
              ;; loops back to the condition at TOP-TAG.
              (append (list top-tag
                            (make-ast-if
                             :cond cond-expr
                             :then (make-ast-quote :value nil)
                             :else (make-ast-return-from :name nil
                                                         :value (make-ast-quote :value nil))))
                      body-stmts
                      (list (make-ast-go :tag continue-tag))
                      (list continue-tag)
                      (list incr)
                      (list (make-ast-go :tag top-tag))
                      (when *php-loop-break-target*
                        (list *php-loop-break-target*))))))))

(defun %php-lower-do-while-with-label (cond-expr body-stmts loop-tag)
  "Lower a PHP do/while loop using LOOP-TAG as the continue target."
  (make-ast-block :name nil
    :body (list
           (%php-make-tagbody
            (append (list loop-tag)
                    body-stmts
                    (list (make-ast-if
                           :cond cond-expr
                           :then (make-ast-go :tag loop-tag)
                           :else (make-ast-quote :value nil)))
                    (when *php-loop-break-target*
                      (list *php-loop-break-target*)))))))

(defun php-lower-switch (switch-expr cases default-body break-tag &optional warning-forms)
  "Lower a PHP switch/case/default to a let/tagbody dispatch form."
  (let ((value-sym (gensym "SWITCH-VAL-"))
        (default-tag (when default-body (gensym "SWITCH-DEFAULT-"))))
    (let* ((case-labels (loop repeat (length cases) collect (gensym "SWITCH-CASE-")))
           (dispatch-forms
            (append
             (loop for case in cases
                   for case-val = (car case)
                   for label in case-labels
                   collect (make-ast-if
                            :cond (make-ast-call
                                   :func (make-ast-var :name 'equal)
                                   :args (list (make-ast-var :name value-sym) case-val))
                            :then (make-ast-go :tag label)
                            :else (make-ast-quote :value nil)))
              (list (make-ast-go :tag (or default-tag break-tag)))))
            (case-forms
             (loop for case in cases
                   for label in case-labels
                   append (list* label (cdr case))))
            (default-forms
             (when default-body
               (list* default-tag default-body))))
      (let ((switch-form
              (make-ast-let
               :bindings (list (cons value-sym switch-expr))
               :body (list (make-ast-block :name nil
                              :body (list (%php-make-tagbody
                                           (append dispatch-forms
                                                   case-forms
                                                   default-forms
                                                   (list break-tag)))))))))
        (if warning-forms
            (make-ast-progn :forms (append warning-forms (list switch-form)))
            switch-form)))))

(defun %php-make-list-advance (list-sym)
  "Build an AST setq that advances LIST-SYM to (cdr LIST-SYM)."
  (make-ast-setq :var list-sym
                 :value (make-ast-call
                         :func (make-ast-var :name 'cdr)
                         :args (list (make-ast-var :name list-sym)))))

(defun %php-lower-foreach-with-label (arr-expr var-sym body-stmts loop-tag &optional key-sym)
  "Lower a PHP foreach loop using LOOP-TAG as the continue target."
  (let ((list-sym (gensym "FOREACH-LIST-")))
    (if key-sym
        (let ((pair-sym (gensym "FOREACH-PAIR-")))
          (make-ast-let
           :bindings (list (cons list-sym
                                 (make-ast-call :func (make-ast-var :name '%php-foreach-pairs)
                                                :args (list arr-expr)))
                           (cons pair-sym (make-ast-quote :value nil)))
           :body (list (%php-lower-while-with-label
                        (make-ast-var :name list-sym)
                        (list (make-ast-setq
                               :var pair-sym
                               :value (make-ast-call
                                       :func (make-ast-var :name 'car)
                                       :args (list (make-ast-var :name list-sym))))
                              (make-ast-let
                               :bindings (list (cons key-sym
                                                     (make-ast-call
                                                      :func (make-ast-var :name 'car)
                                                      :args (list (make-ast-var :name pair-sym))))
                                               (cons var-sym
                                                     (make-ast-call
                                                      :func (make-ast-var :name 'cdr)
                                                      :args (list (make-ast-var :name pair-sym)))))
                               :body (append body-stmts
                                             (list (%php-make-list-advance list-sym)))))
                        loop-tag))))
        (make-ast-let
         :bindings (list (cons list-sym
                               (make-ast-call :func (make-ast-var :name '%php-foreach-values)
                                              :args (list arr-expr))))
         :body (list (%php-lower-while-with-label
                      (make-ast-var :name list-sym)
                      (list (make-ast-let
                             :bindings (list (cons var-sym
                                                   (make-ast-call
                                                    :func (make-ast-var :name 'car)
                                                    :args (list (make-ast-var :name list-sym)))))
                             :body (append body-stmts
                                           (list (%php-make-list-advance list-sym)))))
                      loop-tag))))))

(defun %php-exception-object-cond (expr)
  "Build a predicate call testing whether EXPR is a PHP exception payload."
  (%php-call 'cl-cc/php::%php-exception-object-p expr))

(defun %php-exception-match-cond (expr class-name)
  "Build a predicate call testing whether EXPR matches PHP catch CLASS-NAME."
  (%php-call 'cl-cc/php::%php-exception-matches-p
             expr
             (make-ast-quote :value class-name)))

(defun %php-rethrow-exception (expr)
  "Build a VM throw that propagates an unmatched PHP exception payload."
  (make-ast-throw :tag (make-ast-quote :value 'php-exception)
                  :value expr))

(defun %php-catch-body (exception-sym var-sym body)
  "Return BODY with PHP catch variable VAR-SYM bound to EXCEPTION-SYM when present."
  (if var-sym
      (make-ast-let :bindings (list (cons var-sym
                                          (%php-call 'cl-cc/php::%php-exception-value
                                                     (make-ast-var :name exception-sym))))
                     :body body)
      (make-ast-progn :forms body)))

(defun %php-catch-dispatch (exception-sym clauses)
  "Build nested PHP catch dispatch for EXCEPTION-SYM and CATCH CLAUSES."
  (let ((exception-var (make-ast-var :name exception-sym)))
    (if clauses
        (destructuring-bind (class-name var-sym . body) (first clauses)
          (make-ast-if :cond (%php-exception-match-cond exception-var class-name)
                       :then (%php-catch-body exception-sym var-sym body)
                       :else (%php-catch-dispatch exception-sym (rest clauses))))
        (%php-rethrow-exception exception-var))))

(defun %php-lower-try-catches (try-body clauses)
  "Lower PHP try/catch using VM catch/throw plus PHP class-matching helpers."
  (let ((exception-sym (gensym "PHP-EXCEPTION-RESULT-")))
    (make-ast-let
     :bindings (list (cons exception-sym
                           (make-ast-catch :tag (make-ast-quote :value 'php-exception)
                                           :body try-body)))
     :body (list (make-ast-if
                   :cond (%php-exception-object-cond (make-ast-var :name exception-sym))
                   :then (%php-catch-dispatch exception-sym clauses)
                   :else (make-ast-var :name exception-sym))))))
