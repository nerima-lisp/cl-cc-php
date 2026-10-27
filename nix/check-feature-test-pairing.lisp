(require :asdf)

(defun feature-records ()
  (with-open-file (input "nix/feature-dependencies.sexp")
    (let ((*read-eval* nil))
      (read input))))

(defun record-string (record key)
  (let ((value (getf record key)))
    (unless (stringp value)
      (error "Feature record lacks a string ~S field: ~S" key record))
    value))

(defun ensure-unique (values description)
  (unless (= (length values)
             (length (remove-duplicates (copy-list values) :test #'equal)))
    (error "Duplicate ~A values: ~S" description values)))

(defun declared-test-directories (records)
  (mapcar (lambda (record)
            (record-string record :test-dir))
          records))

(defun observed-test-directories ()
  (sort (mapcar (lambda (directory)
                  (format nil "t/~A"
                          (car (last (pathname-directory directory)))))
                (uiop:subdirectories #p"t/"))
        #'string<))

(let* ((records (feature-records))
       (features (mapcar (lambda (record)
                           (record-string record :feature))
                         records))
       (packages (mapcar (lambda (record)
                           (record-string record :domain-package))
                         records))
       (test-directories (declared-test-directories records)))
  (unless records
    (error "No feature records found"))
  (ensure-unique features "feature")
  (ensure-unique packages "domain package")
  (ensure-unique test-directories "test directory")
  (loop for feature in features
        for package in packages
        for test-directory in test-directories
        unless (string= package (format nil "cl-cc/php/~A" feature))
          do (error "Feature ~A maps to unexpected package ~A" feature package)
        unless (string= test-directory (format nil "t/~A" feature))
          do (error "Feature ~A maps to unexpected test directory ~A"
                    feature test-directory))
  (unless (equal (sort (copy-list test-directories) #'string<)
                 (observed-test-directories))
    (error "Declared test directories ~S do not match directories under t/: ~S"
           test-directories (observed-test-directories)))
  (format t "feature-test pairing: ~D features map one-to-one to packages and t/<feature> directories~%"
          (length records)))
