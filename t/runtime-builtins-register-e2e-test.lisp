;;;; runtime-builtins-register-e2e-test.lisp — src/runtime-builtins-register.lisp — builtin
;;;; dispatch, end to end.
;;;;
;;;; Reaches a builtin only by calling its PHP name from PHP source, so this is the suite that would
;;;; catch a name missing from the registry tables.

(in-package :cl-cc-php/test)

(describe "PHP compile e2e: builtins"


(it-sequential "php-runtime-yield-helper-preserves-value"
  (expect (cl-cc/php:%php-yield 42) :to-equal '(:yield 42))
  (expect (cl-cc/php:%php-yield-from '(1 2)) :to-equal '(:yield-from (1 2))))


(it-sequential "php-runtime-exception-payload-matches-class"
  (let ((payload (cl-cc/php:%php-make-exception 'ex :value)))
    (expect (cl-cc/php:%php-exception-object-p payload) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-value payload) :to-be :value)
    (expect (cl-cc/php:%php-exception-matches-p payload 'ex) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload '(other ex)) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload 'other) :to-be-falsy)))


(it-sequential "php-runtime-concat-stringifies-values"
  (expect (cl-cc/php:%php-concat "Hello " 42) :to-equal "Hello 42")
  (expect (cl-cc/php:%php-concat "x" t) :to-equal "x1")
  (expect (cl-cc/php:%php-concat "x" cl-cc/php:+php-null+) :to-equal "x"))


; tab


  (it-sequential "php-e2e-symbol-registered-builtins"
  (cl-cc/php::%php-register-all-builtins)
  (expect (cl-cc/php::%php-lookup-builtin-symbol "echo") :to-be 'cl-cc/php::%php-echo)
  (expect (cl-cc/php::%php-lookup-builtin-symbol "print") :to-be 'cl-cc/php::%php-print)
  (expect (with-output-to-string (out)
                    (let ((*standard-output* out))
                      (funcall (cl-cc/php::%php-lookup-builtin "echo") "a" "b"))) :to-equal "ab")
  (expect (with-output-to-string (out)
                    (let ((*standard-output* out))
                      (princ (funcall (cl-cc/php::%php-lookup-builtin "print") "c")))) :to-equal "c1")
  (expect (%php-run-capture "<?php function g(){yield 1;yield 2;} echo count(iterator_to_array(g()));") :to-equal "2")
  (expect (%php-run-capture "<?php function g(){yield 1;yield 2;yield 3;} echo iterator_count(g());") :to-equal "3")
  (expect (%php-run-capture "<?php echo is_float(lcg_value())?'f':'n';") :to-equal "f")
  (expect (%php-run-capture "<?php $x=5; echo settype($x,'string')?'ok':'f';") :to-equal "ok")
  (expect (%php-run-capture "<?php echo is_array(sscanf('a b','%s %s'))?'arr':'x';") :to-equal "arr")
  (expect (%php-run-capture "<?php class C{} echo is_array(class_implements(new C()))?'arr':'x';") :to-equal "arr")
  (expect (%php-run-capture "<?php $loader=function($c){}; echo spl_autoload_register($loader)?'t':'f'; echo spl_autoload_unregister($loader)?'u':'n';") :to-equal "tu"))


(it-sequential "php-e2e-math-builtins-are-symbol-registered"
  (dolist (name '("sin" "cos" "tan" "log" "exp" "asin" "acos" "atan"
                  "sinh" "cosh" "tanh" "is_nan" "mt_srand" "srand"))
    (expect (cl-cc/php::%php-lookup-builtin-symbol name) :to-be-truthy))
  (expect (%php-run-capture "<?php echo round(sin('1.5707963267948966'));") :to-equal "1")
  (expect (%php-run-capture "<?php echo round(log('8', '2'));") :to-equal "3"))


(it-sequential "php-e2e-deprecated-each-is-absent"
  (expect (%php-run-capture
                   "<?php echo function_exists('each')?'present':'absent';") :to-equal "absent"))


(it-sequential "php-e2e-nl-langinfo-locale-metadata"
  (expect (%php-run-capture
                   "<?php echo function_exists('nl_langinfo')?'present':'absent';
echo ':'.nl_langinfo(CODESET);
echo ':'.nl_langinfo(ABDAY_1);
echo ':'.nl_langinfo(DAY_2);
echo ':'.nl_langinfo(ABMON_12);
echo ':'.nl_langinfo(MON_12);
echo ':'.nl_langinfo(RADIXCHAR);
echo ':'.nl_langinfo(THOUSEP);") :to-equal "present:UTF-8:Sun:Monday:Dec:December:.:,"))


(it-sequential "php-e2e-header-response-model"
  (expect (%php-run-capture
                   "<?php echo function_exists('header')?'present':'absent';
echo ':'.(function_exists('headers_list')?'present':'absent');
echo ':'.(function_exists('headers_sent')?'present':'absent');") :to-equal "present:present:present")
  (let ((cl-cc/php::*php-http-response-code* 200)
        (cl-cc/php::*php-http-headers* nil)
        (cl-cc/php::*php-output-started-p* nil))
    (expect (%php-run-capture
                     "<?php $old = http_response_code(201);
header('HTTP/1.1 404 Not Found');
echo $old.':'.http_response_code().':'.(headers_sent()?'true':'false');") :to-equal "200:404:false"))
  (let ((cl-cc/php::*php-http-response-code* 200)
        (cl-cc/php::*php-http-headers* nil)
        (cl-cc/php::*php-output-started-p* nil))
    (expect (%php-run-capture
                     "<?php header('X-Test: a');
header('X-Test: b');
header('Set-Cookie: a=1', false);
header('Set-Cookie: b=2', false);
echo json_encode(headers_list());") :to-equal "[\"X-Test: b\",\"Set-Cookie: a=1\",\"Set-Cookie: b=2\"]")))


  (it-sequential-each
      (("<?php echo function_exists('extract')?'present':'absent';"
        "present")
       ("<?php extract(['a'=>1,'b'=>'two','_c'=>3,'bad-key'=>4,5=>6]); echo $a.':'.$b.':'.$_c.':'.(isset($bad)?'y':'n');"
        "1:two:3:n")
       ("<?php $a='old'; extract(['a'=>'new']); echo $a;"
        "new"))
      "php-e2e-extract-static-array-literal: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo empty($missing)?'empty':'set';"
        "empty")
       ("<?php $a=0; $b='value'; $c=null; echo (empty($a)?'empty':'set').':'.(empty($b)?'empty':'set').':'.(empty($c)?'empty':'set');"
        "empty:set:empty"))
      "php-e2e-empty-undefined-variable: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


(it-sequential "php-e2e-scanf-reads-standard-input"
  (expect (%php-run-capture
                   "<?php echo function_exists('scanf')?'present':'absent';") :to-equal "present")
  (let ((*standard-input* (make-string-input-stream "12 bob 3.5")))
    (expect (%php-run-capture
                     "<?php $v=scanf('%d %s %f'); echo $v[0].':'.$v[1].':'.$v[2];") :to-equal "12:bob:3.5"))
  (let ((*standard-input* (make-string-input-stream "42-ada")))
    (expect (%php-run-capture
                     "<?php $r=scanf('%d-%s',$id,$name); echo $r.':'.$id.':'.$name;") :to-equal "2:42:ada")))


(it-sequential "php-e2e-standard-stream-constants-are-backed-by-streams"
  (expect (%php-run-capture
                   "<?php echo (STDIN===null?'bad':'in'); echo ':'; fwrite(STDOUT,'out'); echo ':'; echo (STDERR===null?'bad':'err');") :to-equal "in:out:err"))


  (it-sequential-each
      (("<?php echo function_exists('compact')?'present':'absent';"
        "present")
       ("<?php $name='Ada'; $age=36; $r=compact('name','age','missing'); echo $r['name'].':'.$r['age'];"
        "Ada:36")
       ("<?php $x='yes'; $r=compact(['x']); echo $r['x'];"
        "yes")
       ("<?php $x='ok'; $y=7; $r=compact(['x',['y']]); echo $r['x'].':'.$r['y'];"
        "ok:7"))
      "php-e2e-compact-captures-static-visible-variables: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php $x=5; settype($x,'string'); echo gettype($x).':'.$x;"
        "string:5")
       ("<?php $x='12abc'; settype($x,'integer'); echo gettype($x).':'.$x;"
        "integer:12")
       ("<?php $x='0'; settype($x,'bool'); echo gettype($x).':'.($x?'true':'false');"
        "boolean:false")
       ("<?php $x='value'; settype($x,'null'); echo gettype($x).':'.$x;"
        "NULL:")
       ("<?php $x=7; settype($x,'array'); echo gettype($x).':'.$x[0];"
        "array:7")
       ("<?php $x=7; settype($x,'object'); echo gettype($x).':'.get_class($x).':'.$x->scalar;"
        "object:stdClass:7")
       ("<?php $x=['name'=>'ada']; settype($x,'object'); echo gettype($x).':'.get_class($x).':'.$x->name;"
        "object:stdClass:ada")
       ("<?php $x=9; echo settype($x,'bogus')?'ok':'fail'; echo ':'.$x;"
        "fail:9"))
      "php-e2e-settype-mutates-variable: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php $v=sscanf('12 bob 3.5','%d %s %f'); echo $v[0].':'.$v[1].':'.$v[2];"
        "12:bob:3.5")
       ("<?php $r=sscanf('12-bob','%d-%s',$id,$name); echo $r.':'.$id.':'.$name;"
        "2:12:bob")
       ("<?php $v=sscanf('abcdef','%2c%2s'); echo $v[0].':'.$v[1];"
        "ab:cd")
       ("<?php $v=sscanf('ff 010','%x %i'); echo $v[0].':'.$v[1];"
        "255:8")
       ("<?php $r=sscanf('42 nope','%d:%s',$n,$s); echo $r.':'.$n.':'.$s;"
        "1:42:"))
      "php-e2e-sscanf-format-parsing: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))

  (it-sequential-each
      (("<?php $v=sscanf('1 2 3','%d %*d %d'); echo count($v).':'.$v[0].':'.$v[1];"
        "2:1:3")
       ("<?php $v=sscanf('50%','%d%%'); echo count($v).':'.$v[0];"
        "1:50")
       ("<?php $v=sscanf('17','%o'); echo $v[0];"
        "15")
       ("<?php $v=sscanf('-5','%u'); echo count($v);"
        "0")
       ("<?php $v=sscanf('3.5','%e'); echo $v[0];"
        "3.5")
       ("<?php $v=sscanf('3.5','%g'); echo $v[0];"
        "3.5"))
      "php-e2e-sscanf-suppress-literal-octal-unsigned-and-float-aliases: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo intval('42');"
        "42")
       ("<?php echo intval('1A',16);"
        "26")
       ("<?php echo intval('0x1A',16);"
        "26")
       ("<?php echo intval('077',8);"
        "63")
       ("<?php echo intval('1010',2);"
        "10")
       ("<?php echo intval('0x1A',0);"
        "26")
       ("<?php echo intval('017',0);"
        "15")
       ("<?php echo intval('0b101',0);"
        "5")
       ("<?php echo intval('-FF',16);"
        "-255")
       ("<?php echo intval('42abc');"
        "42")
       ("<?php echo intval('42',10);"
        "42"))
      "php-e2e-intval-base: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo gmdate('D',0);"
        "Thu")
       ("<?php echo gmdate('l',0);"
        "Thursday")
       ("<?php echo gmdate('N',0);"
        "4")
       ("<?php echo gmdate('w',0);"
        "4")
       ("<?php echo gmdate('D',86400*3);"
        "Sun")
       ("<?php echo gmdate('w',86400*3);"
        "0")
       ("<?php echo gmdate('N',86400*3);"
        "7")
       ("<?php echo gmdate('g:i A',3661);"
        "1:01 AM")
       ("<?php echo gmdate('Y-m-d H:i:s',86400);"
        "1970-01-02 00:00:00")
       ("<?php echo gmdate('l, F j, Y',0);"
        "Thursday, January 1, 1970"))
      "php-e2e-gmdate-weekday: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo gmdate('L',0);"
        "0")
       ("<?php echo gmdate('L',63072000);"
        "1")
       ("<?php echo gmdate('t',0);"
        "31")
       ("<?php echo gmdate('t',2678400);"
        "28")
       ("<?php echo gmdate('t',65750400);"
        "29")
       ("<?php echo gmdate('z',0);"
        "0")
       ("<?php echo gmdate('z',86400);"
        "1")
       ("<?php echo gmdate('jS',0);"
        "1st")
       ("<?php echo gmdate('jS',86400);"
        "2nd")
       ("<?php echo gmdate('jS',172800);"
        "3rd")
       ("<?php echo gmdate('jS',864000);"
        "11th")
       ("<?php echo gmdate('jS',1728000);"
        "21st"))
      "php-e2e-gmdate-formats: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo gmmktime(0,0,0,1,2,1970);"
        "86400")
       ("<?php echo gmdate('Y-m-d',mktime(0,0,0,12,25,2000));"
        "2000-12-25")
       ("<?php echo json_encode(array_values(array_udiff([1,2,3,4],[2,4],fn($a,$b)=>$a-$b)));"
        "[1,3]")
       ("<?php echo json_encode(array_values(array_uintersect([1,2,3,4],[2,4,5],fn($a,$b)=>$a-$b)));"
        "[2,4]")
       ("<?php echo json_encode(array_values(array_udiff(['A','b','C'],['a','B'],fn($x,$y)=>strcasecmp($x,$y))));"
        "[\"C\"]"))
      "php-e2e-date-construct-and-udiff: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  )
