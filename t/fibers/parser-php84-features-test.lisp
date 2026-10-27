(in-package :cl-cc/php/fibers/test)

(describe "PHP Fiber tests"
  (it-sequential "new Fiber(callback) lowers to a PHP object wrapper via %php-fiber-make."
    (let ((fiber (cl-cc/php:%php-fiber-make (lambda () 42))))
      (expect (hash-table-p fiber) :to-be-truthy)
      (expect (gethash "__class__" fiber) :to-equal "Fiber")
      (expect (cl-cc/php/fibers:%php-fiber-started-p fiber) :to-be-falsy)
      (expect (cl-cc/php/fibers:%php-fiber-terminated-p fiber) :to-be-falsy)
      (expect (= 42 (cl-cc/php:%php-fiber-start fiber)) :to-be-truthy)
      (expect (cl-cc/php/fibers:%php-fiber-started-p fiber) :to-be-truthy)
      (expect (cl-cc/php/fibers:%php-fiber-terminated-p fiber) :to-be-truthy)))
  (it-sequential "Fiber::start() runs the callback and returns its result when it does not suspend."
(let* ((fiber (cl-cc/php:%php-fiber-make (lambda () 99)))
         (result (cl-cc/php:%php-fiber-start fiber)))
    (expect (= 99 result) :to-be-truthy)
    (expect (cl-cc/php/fibers:%php-fiber-started-p fiber) :to-be-truthy)
    (expect (cl-cc/php/fibers:%php-fiber-terminated-p fiber) :to-be-truthy)))
  (it-sequential "Starting an already-started Fiber signals an error."
(let ((fiber (cl-cc/php:%php-fiber-make (lambda () 1))))
    (cl-cc/php:%php-fiber-start fiber)
    (signals error (cl-cc/php:%php-fiber-start fiber))))
  (it-sequential "%php-fiber-get-return returns the final return value of a terminated Fiber."
(let* ((fiber (cl-cc/php:%php-fiber-make (lambda () :done))))
    (cl-cc/php:%php-fiber-start fiber)
    (expect (cl-cc/php/fibers:%php-fiber-get-return fiber) :to-be :done)))
  (it-sequential "%php-fiber-get-return signals an error when the fiber has not yet terminated."
    (let ((fiber (cl-cc/php:%php-fiber-make (lambda () :done))))
      ;; Not started yet
      (signals error (cl-cc/php/fibers:%php-fiber-get-return fiber))
      (expect (cl-cc/php:%php-fiber-start fiber) :to-be :done)))
  (it-sequential "%php-fiber-suspend signals an error when called outside a running Fiber."
    (signals error (cl-cc/php:%php-fiber-suspend "x")))
  (it-sequential "isRunning is false before start and after termination, true during the callback."
    (let* (fiber
           (fiber-was-running-p :not-observed))
      (setf fiber
            (cl-cc/php:%php-fiber-make
             (lambda ()
               (setf fiber-was-running-p (cl-cc/php/fibers:%php-fiber-running-p fiber))
               1)))
      (expect (cl-cc/php/fibers:%php-fiber-running-p fiber) :to-be nil)
      (cl-cc/php:%php-fiber-start fiber)
      (expect fiber-was-running-p :to-be-truthy)
      (expect (cl-cc/php/fibers:%php-fiber-running-p fiber) :to-be nil)))
  (it-sequential "isSuspended is false for a Fiber that never suspends."
    (let ((fiber (cl-cc/php:%php-fiber-make (lambda () 1))))
      (cl-cc/php:%php-fiber-start fiber)
      (expect (cl-cc/php/fibers:%php-fiber-suspended-p fiber) :to-be nil)))
  (it-sequential "resuming a Fiber that never suspended (never started) signals an error."
    (let ((fiber (cl-cc/php:%php-fiber-make (lambda () 1))))
      (signals error (cl-cc/php:%php-fiber-resume fiber))))
  (it-sequential
    "resuming a suspended Fiber terminates it and returns null: there is no true resume-fn"
    ;; %php-fiber-start's CATCH/THROW-based suspend unwinds the whole call
    ;; stack, so there is nothing left to continue from -- RESUME-FN is never
    ;; set (see runtime-fibers.lisp's own header comment). This locks in that
    ;; documented, intentional limitation rather than a resumability this
    ;; runtime doesn't actually have.
    (let ((fiber (cl-cc/php:%php-fiber-make
                  (lambda () (cl-cc/php:%php-fiber-suspend "paused")))))
      (cl-cc/php:%php-fiber-start fiber)
      (expect (cl-cc/php/fibers:%php-fiber-suspended-p fiber) :to-be-truthy)
      (expect (cl-cc/php:%php-null-p (cl-cc/php:%php-fiber-resume fiber "value")) :to-be-truthy)
      (expect (cl-cc/php/fibers:%php-fiber-terminated-p fiber) :to-be-truthy))))
