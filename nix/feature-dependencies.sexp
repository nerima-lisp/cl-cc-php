(
 (:feature "syntax"
  :source-dirs ("src/syntax")
  :test-dir "t/syntax"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/syntax"
  :infra-package nil
  :depends-on ())
 (:feature "errors"
  :source-dirs ("src/errors")
  :test-dir "t/errors"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/errors"
  :infra-package nil
  :depends-on ("syntax"))
 (:feature "types"
  :source-dirs ("src/types")
  :test-dir "t/types"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/types"
  :infra-package nil
  :depends-on ("syntax"))
 (:feature "expressions"
  :source-dirs ("src/expressions")
  :test-dir "t/expressions"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/expressions"
  :infra-package nil
  :depends-on ("syntax" "types" "errors"))
 (:feature "arrays"
  :source-dirs ("src/arrays")
  :test-dir "t/arrays"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/arrays"
  :infra-package nil
  :depends-on ("syntax" "expressions" "types" "errors"))
 (:feature "strings"
  :source-dirs ("src/strings")
  :test-dir "t/strings"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/strings"
  :infra-package nil
  :depends-on ("syntax" "expressions"))
 (:feature "attributes"
  :source-dirs ("src/attributes")
  :test-dir "t/attributes"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/attributes"
  :infra-package nil
  :depends-on ("syntax" "expressions"))
 (:feature "match"
  :source-dirs ("src/match")
  :test-dir "t/match"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/match"
  :infra-package nil
  :depends-on ("syntax" "expressions" "arrays" "errors"))
 (:feature "generators"
  :source-dirs ("src/generators")
  :test-dir "t/generators"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/generators"
  :infra-package nil
  :depends-on ("syntax" "expressions" "arrays" "types"))
 (:feature "statements"
  :source-dirs ("src/statements")
  :test-dir "t/statements"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/statements"
  :infra-package nil
  :depends-on ("syntax" "expressions" "generators" "arrays" "types" "errors"))
 (:feature "functions"
  :source-dirs ("src/functions")
  :test-dir "t/functions"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/functions"
  :infra-package nil
  :depends-on ("syntax" "expressions" "statements" "arrays" "attributes" "types" "errors"))
 (:feature "classes"
  :source-dirs ("src/classes")
  :test-dir "t/classes"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/classes"
  :infra-package nil
  :depends-on ("syntax" "expressions" "statements" "functions" "arrays" "attributes" "types" "errors"))
 (:feature "fibers"
  :source-dirs ("src/fibers")
  :test-dir "t/fibers"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/fibers"
  :infra-package nil
  :depends-on ("syntax" "expressions" "functions" "types"))
 (:feature "stdlib"
  :source-dirs ("src/stdlib")
  :test-dir "t/stdlib"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/stdlib"
  :infra-package nil
  :depends-on ("syntax" "expressions" "functions" "classes" "generators" "fibers" "arrays" "strings" "types" "errors"))
 (:feature "backend"
  :source-dirs ("src/backend")
  :test-dir "t/backend"
  :facade-packages ("cl-cc/php")
  :domain-package "cl-cc/php/backend"
  :infra-package nil
  :depends-on ("syntax")))
