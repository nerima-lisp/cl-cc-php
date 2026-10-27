(in-package :cl-cc/php/generators/test)

(describe "PHP generator tests"
  (it-sequential "make-generator eagerly collects every %php-yield call the thunk makes"
  (let ((gen (cl-cc/php:%php-make-generator
              (lambda ()
                (cl-cc/php:%php-yield 1)
                (cl-cc/php:%php-yield 2)
                (cl-cc/php:%php-yield 3)
                :done))))
    (expect (cl-cc/php:%php-generator-p gen) :to-be-truthy)
    (expect (cl-cc/php:%php-generator-get-return gen) :to-be :done)
    (expect (cl-cc/php/generators:%php-generator-drain-values gen) :to-equal '(1 2 3))))
  (it-sequential "make-generator swallows an error raised by the thunk, keeping values collected so far"
  (let ((gen (cl-cc/php:%php-make-generator
              (lambda ()
                (cl-cc/php:%php-yield 1)
                (error "boom")))))
    (expect (cl-cc/php/generators:%php-generator-drain-values gen) :to-equal '(1))))
  (it-sequential "generator-p is false for an ordinary value"
  (expect (cl-cc/php:%php-generator-p 42) :to-be nil)
  (expect (cl-cc/php:%php-generator-p "not a generator") :to-be nil))
  (it-sequential "%php-yield with no active generator returns a (:yield VALUE) inspection marker"
  ;; %PHP-YIELD/-FROM's fallback path for a pure host call outside any
  ;; generator body (*CURRENT-GENERATOR* unbound and no VM state active).
  (expect (cl-cc/php:%php-yield 42) :to-equal '(:yield 42))
  (expect (cl-cc/php:%php-yield-from '(1 2)) :to-equal '(:yield-from (1 2)))))
