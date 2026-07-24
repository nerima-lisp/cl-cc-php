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


(it-sequential "php-e2e-var-dump-and-export"
  (expect (%php-run-capture "<?php var_dump(42);") :to-equal "int(42)")
  (expect (%php-run-capture "<?php var_dump('hi');") :to-equal "string(2) \"hi\"")
  (expect (%php-run-capture "<?php var_dump(true);") :to-equal "bool(true)")
  (expect (%php-run-capture "<?php var_dump(1.5);") :to-equal "float(1.5)")
  (expect (%php-run-capture "<?php var_dump(null);") :to-equal "NULL")
  (expect (%php-run-capture "<?php var_dump([1,2]);") :to-equal (format nil "array(2) {~%  [0]=>~%  int(1)~%  [1]=>~%  int(2)~%}"))
  (expect (%php-run-capture "<?php var_export(42);") :to-equal "42")
  (expect (%php-run-capture "<?php var_export('hi');") :to-equal "'hi'")
  (expect (%php-run-capture "<?php var_export(true);") :to-equal "true")
  (expect (%php-run-capture "<?php var_export([1,2]);") :to-equal (format nil "array (~%  0 => 1,~%  1 => 2,~%)"))
  (expect (%php-run-capture "<?php echo var_export(7, true);") :to-equal "7"))


  (it-sequential-each
      (("<?php echo fmod(7,3);"
        "1")
       ("<?php echo fmod(-7,3);"
        "-1")
       ("<?php echo round(atan2(1,1),4);"
        "0.7854")
       ("<?php echo log10(1000);"
        "3")
       ("<?php echo log2(8);"
        "3")
       ("<?php echo hypot(3,4);"
        "5")
       ("<?php echo round(deg2rad(180),5);"
        "3.14159")
       ("<?php echo round(rad2deg(3.141592653589793),2);"
        "180")
       ("<?php echo base_convert('ff',16,2);"
        "11111111")
       ("<?php echo base_convert('255',10,16);"
        "ff")
       ("<?php echo is_finite(1.5)?'y':'n';"
        "y")
       ("<?php echo is_infinite(fdiv(1,0))?'y':'n';"
        "y"))
      "php-e2e-math-non-cl-named-builtins: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo serialize(42);"
        "i:42;")
       ("<?php echo serialize('hello');"
        "s:5:\"hello\";")
       ("<?php echo serialize(true);"
        "b:1;")
       ("<?php echo serialize(false);"
        "b:0;")
       ("<?php echo serialize(null);"
        "N;")
       ("<?php echo serialize(3.14);"
        "d:3.14;")
       ("<?php echo serialize([1,2,3]);"
        "a:3:{i:0;i:1;i:1;i:2;i:2;i:3;}")
       ("<?php echo serialize(['a'=>1,'b'=>2]);"
        "a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}")
       ("<?php class C { public $x = 7; } echo serialize(new C());"
        "O:1:\"C\":1:{s:1:\"x\";i:7;}")
       ("<?php class C { public $x = 7; public $y = 9; function __sleep(){ return ['y','x']; } } echo serialize(new C());"
        "O:1:\"C\":2:{s:1:\"y\";i:9;s:1:\"x\";i:7;}")
       ("<?php class C { public $x = 7; public $y = 9; function __sleep(){ return ['y']; } function __wakeup(){ $this->x = 6; } } $u = unserialize(serialize(new C())); echo $u->x + $u->y;"
        "15")
       ("<?php class C { public $x = 7; public $y = 9; function __serialize(){ return ['y'=>$this->y, 'x'=>$this->x]; } } echo serialize(new C());"
        "O:1:\"C\":2:{s:1:\"y\";i:9;s:1:\"x\";i:7;}")
       ("<?php class C { public $x = 7; public $y = 9; function __serialize(){ return ['y'=>$this->y, 'x'=>$this->x]; } function __unserialize($data){ $this->y = $data['y']; $this->x = $data['x'] - 1; } } $u = unserialize(serialize(new C())); echo $u->x + $u->y;"
        "15")
       ("<?php echo unserialize(serialize(42))+8;"
        "50")
       ("<?php $x=unserialize(serialize([1,2,['k'=>'v']])); echo $x[2]['k'];"
        "v")
       ("<?php class C { public $x = 7; } $u = unserialize(serialize(new C())); echo $u->x;"
        "7")
       ("<?php echo unserialize('b:1;')?'T':'F';"
        "T")
       ("<?php echo unserialize('garbage')?'T':'F';"
        "F"))
      "php-e2e-serialize-unserialize: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo \"a\\.b\";"
        "a\\.b")
       ("<?php echo \"\\d\\w\";"
        "\\d\\w")
       ("<?php echo strlen(\"a\\nb\");"
        "3")
       ("<?php echo \"\\x41\";"
        "A")
       ("<?php echo \"\\u{48}\";"
        "H")
       ("<?php echo strlen(\"\\t\");"
        "1"))
      "php-e2e-string-escape-preservation: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))    ; tab


  (it-sequential-each
      (("<?php echo md5('abc');"
        "900150983cd24fb0d6963f7d28e17f72")
       ("<?php echo md5('');"
        "d41d8cd98f00b204e9800998ecf8427e")
       ("<?php echo bin2hex(md5('abc', true));"
        "900150983cd24fb0d6963f7d28e17f72")
       ("<?php echo sha1('abc');"
        "a9993e364706816aba3e25717850c26c9cd0d89d")
       ("<?php echo sha1('');"
        "da39a3ee5e6b4b0d3255bfef95601890afd80709")
       ("<?php echo bin2hex(sha1('abc', true));"
        "a9993e364706816aba3e25717850c26c9cd0d89d"))
      "php-e2e-md5-sha1-builtins: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo crc32('');"
        "0")
       ("<?php echo crc32('abc');"
        "891568578")
       ("<?php echo crc32('foo');"
        "2356372769"))
      "php-e2e-crc32-builtin: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo preg_replace_callback('/\\d/', fn($m)=>$m[0]*2, 'a1b2');"
        "a2b4")
       ("<?php echo preg_replace_callback('/[a-z]+/', fn($m)=>strtoupper($m[0]), 'hi there');"
        "HI THERE")
       ("<?php echo preg_replace_callback('/\\d/', fn($m)=>'X', '1234', 2);"
        "XX34")
       ("<?php echo preg_replace_callback(\"/\\d/\", fn($m)=>$m[0]*2, 'a1b2');"
        "a2b4")
       ("<?php echo preg_replace_callback('/(\\w+)=(\\d+)/', fn($m)=>$m[1].':'.$m[2], 'x=12 y=34');"
        "x:12 y:34")
       ("<?php echo preg_replace_callback('/((\\d)(\\d))/', fn($m)=>$m[2].'-'.$m[3], '42');"
        "4-2")
       ("<?php echo preg_replace_callback_array(['/\\d/'=>fn($m)=>'N','/[a-z]/'=>fn($m)=>'L'], 'a1b2');"
        "LNLN")
       ("<?php echo preg_replace_callback_array(['/(\\w)(\\d)/'=>fn($m)=>$m[2].$m[1]], 'a1 b2');"
        "1a 2b"))
      "php-e2e-preg-replace-callback: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo preg_replace('/(\\w)(\\w)/', '$2$1', 'abcd');"
        "badc")
       ("<?php echo preg_replace('/(\\d+)-(\\d+)/', '$2/$1', '12-34');"
        "34/12")
       ("<?php echo preg_replace('/\\d+/', '[$0]', 'a12b');"
        "a[12]b")
       ("<?php echo preg_replace('/(\\w+)/', '${1}!', 'hi');"
        "hi!")
       ("<?php echo preg_replace('/((\\d)(\\d))/', '$2-$3', '42');"
        "4-2")
       ("<?php echo preg_match_all('/\\d/', '1a2b3');"
        "3")
       ("<?php echo preg_match_all('/\\w+/', 'foo bar baz');"
        "3")
       ("<?php echo preg_match_all('/\\d/', 'abc');"
        "0"))
      "php-e2e-preg-capture-groups: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php preg_match('/(\\d+)-(\\d+)/', '12-34', $m); echo $m[1].'|'.$m[2];"
        "12|34")
       ("<?php $r=preg_match('/(\\d+)/', 'abc123', $m); echo $r.':'.$m[0].':'.$m[1];"
        "1:123:123")
       ("<?php preg_match('/(\\w+)@(\\w+)/', 'bob@host', $m); echo $m[1].' at '.$m[2];"
        "bob at host")
       ("<?php echo preg_match('/\\d/', 'abc', $m);"
        "0")
       ("<?php preg_match_all('/(\\d)/', '1a2b3', $m); echo implode(',', $m[1]);"
        "1,2,3")
       ("<?php preg_match_all('/\\d+/', 'a12b34', $m); echo implode(',', $m[0]);"
        "12,34")
       ("<?php $r=preg_match('/\\d/', 'a1b2c3', $m, 0, 3); echo $r.':'.$m[0];"
        "1:2")
       ("<?php preg_match_all('/(\\d)/', 'a1b2c3', $m, 0, 3); echo implode(',', $m[1]);"
        "2,3"))
      "php-e2e-preg-match-out-param: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo ucwords('hello world');"
        "Hello World")
       ("<?php echo ucwords('world order roar');"
        "World Order Roar")
       ("<?php echo ucwords('fluffy vivid');"
        "Fluffy Vivid")
       ("<?php echo ucwords('the QUICK brown');"
        "The QUICK Brown")
       ("<?php echo ucwords('hello-world', '-');"
        "Hello-World"))
      "php-e2e-ucwords-delimiters: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo wordwrap('aaaaaa',3,'|',true);"
        "aaa|aaa")
       ("<?php echo wordwrap('a verylongword b',4,'|',true);"
        "a|very|long|word|b")
       ("<?php echo wordwrap('A very long woooooooord.',8,'|',true);"
        "A very|long|wooooooo|ord.")
       ("<?php echo wordwrap('aaaaaa',3,'|',false);"
        "aaaaaa")
       ("<?php echo wordwrap('aaa bbb ccc',5,'|');"
        "aaa|bbb|ccc")
       ("<?php echo wordwrap('The quick brown fox',10,'|');"
        "The quick|brown fox"))
      "php-e2e-wordwrap-cut: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


(it-sequential "php-e2e-json-encode-pretty"
  (expect (%php-run-capture "<?php echo json_encode(['a'=>1,'b'=>[2,3]]);") :to-equal "{\"a\":1,\"b\":[2,3]}")
  (expect (%php-run-capture "<?php echo json_encode(['a'=>1,'b'=>[2,3]],JSON_PRETTY_PRINT);") :to-equal (format nil "{~%    \"a\": 1,~%    \"b\": [~%        2,~%        3~%    ]~%}"))
  (expect (%php-run-capture "<?php echo json_encode([1,2,3],JSON_PRETTY_PRINT);") :to-equal (format nil "[~%    1,~%    2,~%    3~%]"))
  (expect (%php-run-capture "<?php echo json_encode(['x'=>[],'y'=>1],JSON_PRETTY_PRINT);") :to-equal (format nil "{~%    \"x\": [],~%    \"y\": 1~%}")))


  (it-sequential-each
      (("<?php $d=json_decode('{\"a\":1,\"b\":2}',true); echo $d['a']+$d['b'];"
        "3")
       ("<?php $d=json_decode('{\"name\":\"Bob\",\"age\":30}',true); echo $d['name'].'-'.$d['age'];"
        "Bob-30")
       ("<?php $d=json_decode('{\"x\":{\"y\":[1,2,3]}}',true); echo $d['x']['y'][2];"
        "3")
       ("<?php $d=json_decode('[\"a\",\"bb\",\"ccc\"]'); echo $d[1].strlen($d[2]);"
        "bb3")
       ("<?php echo json_decode('true')?'y':'n';"
        "y")
       ("<?php echo json_decode('not json')===null?'null':'x';"
        "null")
       ("<?php $o=['user'=>'alice','roles'=>['admin','editor'],'active'=>true]; $r=json_decode(json_encode($o),true); echo $r['user'].':'.$r['roles'][1].':'.($r['active']?'y':'n');"
        "alice:editor:y"))
      "php-e2e-json-decode: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo number_format(1234.5);"
        "1,235")
       ("<?php echo number_format(2.5);"
        "3")
       ("<?php echo number_format(0.5);"
        "1")
       ("<?php echo number_format(1234.4);"
        "1,234")
       ("<?php echo number_format(-1234.5);"
        "-1,235")
       ("<?php echo number_format(3.14159,2);"
        "3.14")
       ("<?php echo number_format(1234.567,2);"
        "1,234.57")
       ("<?php echo number_format(1234.5,2,',','.');"
        "1.234,50"))
      "php-e2e-number-format-rounding: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo round(2.5);"
        "3")
       ("<?php echo round(3.5);"
        "4")
       ("<?php echo round(-2.5);"
        "-3")
       ("<?php echo round(0.5);"
        "1")
       ("<?php echo round(2.4);"
        "2")
       ("<?php echo round(-2.4);"
        "-2")
       ("<?php echo round(3.14159,2);"
        "3.14")
       ("<?php echo round(1.95583,2);"
        "1.96")
       ("<?php echo round(1241757,-3);"
        "1242000"))
      "php-e2e-round-half-away: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo sprintf('%e',12345.678);"
        "1.234568e+4")
       ("<?php echo sprintf('%E',0.00012);"
        "1.200000E-4")
       ("<?php echo sprintf('%+d %+d',5,-5);"
        "+5 -5")
       ("<?php echo sprintf('%+05d',42);"
        "+0042")
       ("<?php echo sprintf('%05d',-42);"
        "-0042")
       ("<?php echo sprintf(\"%'*10d\",42);"
        "********42")
       ("<?php echo sprintf(\"%'-10s\",'hi');"
        "--------hi")
       ("<?php echo sprintf('%05d',42);"
        "00042")
       ("<?php echo sprintf('[%-5s]','ab');"
        "[ab   ]")
       ("<?php echo sprintf('%.2f',3.14159);"
        "3.14")
       ("<?php echo sprintf('%x %X %o',255,255,8);"
        "ff FF 10"))
      "php-e2e-sprintf-flags: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo dechex(255);"
        "ff")
       ("<?php echo hexdec('ff');"
        "255")
       ("<?php echo decbin(10);"
        "1010")
       ("<?php echo bindec('1010');"
        "10")
       ("<?php echo decoct(64);"
        "100")
       ("<?php echo octdec('100');"
        "64")
       ("<?php echo dechex(-1);"
        "ffffffffffffffff")
       ("<?php echo hexdec(dechex(48879));"
        "48879"))
      "php-e2e-base-conversions: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo max([3,1,2]);"
        "3")
       ("<?php echo min([3,1,2]);"
        "1")
       ("<?php echo max(1,5,3);"
        "5")
       ("<?php echo max(1,'10',5);"
        "10")
       ("<?php echo min(2.5,2,3);"
        "2")
       ("<?php echo max(42);"
        "42"))
      "php-e2e-max-min: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


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
