;;;; parser-e2e-test.lisp — src/parser.lisp — the parse-and-lower path, driven end to end.
;;;;
;;;; Core language: objects, properties, increments, arrays, control flow.

(in-package :cl-cc-php/test)

(describe
  "PHP compile e2e: core language"
  (it-sequential-each
      (("<?php class C{ public $n=0; } $o=new C(); $o->n++; $o->n++; echo $o->n;"
        "2")
       ("<?php class C{ public $n=10; } $o=new C(); echo $o->n++;" "10")
       ("<?php class C{ public $n=5; } $o=new C(); $o->n--; echo $o->n;" "4")
       ("<?php class C{ public $n=0; function inc(){ $this->n++; } } $o=new C(); $o->inc(); $o->inc(); $o->inc(); echo $o->n;"
        "3")
       ("<?php $a=[0]; $a[0]++; $a[0]++; echo $a[0];" "2")
       ("<?php $a=[5]; $old=$a[0]++; echo $old.'-'.$a[0];" "5-6")
       ("<?php $x='7'; $old=$x++; echo $old.'-'.$x;" "7-8")
       ("<?php $x=null; ++$x; echo $x;" "1")
       ("<?php $x=true; --$x; echo $x;" "0"))
      "php-e2e-postfix-incdec-on-places: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $x++; echo $x;" "1")
       ("<?php echo (++$x).':'.$x;" "1:1")
       ("<?php $x--; echo $x;" "-1")
       ("<?php echo (--$x).':'.$x;" "-1:-1"))
      "php-e2e-incdec-undefined-variable: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-e2e-echo-no-trailing-newline-multi"
    (expect
      (%php-run-capture "<?php echo 'a'; echo 'b'; echo 'c';")
      :to-equal
      "abc"))
  (it-sequential
    "php-e2e-echo-no-trailing-newline-multiarg"
    (expect (%php-run-capture "<?php echo 'x', 'y', 'z';") :to-equal "xyz"))
  (it-sequential
    "php-e2e-echo-interior-newline-preserved"
    (expect
      (%php-run-capture "<?php echo \"p\\n\"; echo 'q';")
      :to-equal
      (format nil "p~%q")))
  (it-sequential
    "php-e2e-inline-html-verbatim"
    (expect
      (%php-run-capture "<?php echo 1; ?>hello<?php echo 2;")
      :to-equal
      "1hello2"))
  (it-sequential-each
      (("<?php declare(strict_types=1); echo 7;" "7")
       ("<?php declare(ticks=1) { echo 'A'; echo 'B'; } echo 'C';" "ABC")
       ("<?php declare(ticks=1) echo 'X'; echo 'Y';" "XY")
       ("<?php declare(ticks=1): echo 'A'; echo 'B'; enddeclare; echo 'C';" "ABC"))
      "php-e2e-declare-directives: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php ob_start(); echo 'a'; $s=ob_get_clean(); echo $s; echo 'b';" "ab")
       ("<?php ob_start(); echo 'x'; $s=ob_get_contents(); ob_end_clean(); echo $s.'y';"
        "xy")
       ("<?php ob_start(); echo 'a'; ob_start(); echo 'x'; ob_end_clean(); echo 'b'; echo ob_get_clean();"
        "ab")
       ("<?php ob_start(); ?>html<?php $s=ob_get_clean(); echo $s.'!';" "html!"))
      "php-e2e-output-buffering-builtins: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo ini_get('default_charset');" "UTF-8")
       ("<?php $old=ini_set('default_charset','Shift_JIS'); echo $old.':'.ini_get('default_charset'); ini_set('default_charset',$old);"
        "UTF-8:Shift_JIS")
       ("<?php error_reporting(32767); $old=error_reporting(0); echo $old.':'.error_reporting().':'.ini_get('error_reporting'); error_reporting($old);"
        "32767:0:0")
       ("<?php error_reporting(32767); $old=ini_set('error_reporting','5'); echo $old.':'.error_reporting().':'.ini_get('error_reporting'); error_reporting($old);"
        "32767:5:5")
       ("<?php echo ini_get('definitely_missing')===false?'false':'value';"
        "false"))
      "php-e2e-ini-get-set-and-error-reporting: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function h($errno,$errstr,$file,$line){ echo 'H:'.$errno.':'.$errstr; return true; } set_error_handler('h', E_USER_WARNING); trigger_error('boom', E_USER_WARNING); restore_error_handler();"
        "H:512:boom")
       ("<?php function only_notice($errno,$errstr){ echo 'handled'; return true; } set_error_handler('only_notice', E_USER_NOTICE); trigger_error('masked', E_USER_WARNING); restore_error_handler();"
        "masked")
       ("<?php function h1($errno,$errstr){ echo 'one'; return true; } function h2($errno,$errstr){ echo 'two'; return true; } set_error_handler('h1'); $old=set_error_handler('h2'); echo $old.':'; trigger_error('x', E_USER_NOTICE); restore_error_handler(); restore_error_handler();"
        "h1:two")
       ("<?php function eh($e){ echo 'e'; } set_exception_handler('eh'); $old=set_exception_handler(function($e){ echo 'x'; }); echo $old.':ok'; restore_exception_handler(); restore_exception_handler();"
        "eh:ok"))
      "php-e2e-error-and-exception-handler-registration: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php @trigger_error('hidden', E_USER_NOTICE); echo 'ok';" "ok")
       ("<?php function h($errno,$errstr){ echo 'handler'; return true; } set_error_handler('h'); @trigger_error('hidden', E_USER_NOTICE); restore_error_handler(); echo 'ok';"
        "ok")
       ("<?php error_reporting(E_ALL); $v=@trigger_error('hidden', E_USER_NOTICE); echo $v.':'.error_reporting();"
        "1:32767"))
      "php-e2e-error-suppression-operator: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $old=date_default_timezone_get(); date_default_timezone_set('UTC'); $prev=date_default_timezone_get(); date_default_timezone_set('Asia/Tokyo'); echo $prev.':'.date_default_timezone_get().':'.ini_get('date.timezone').':'.date('H:i',0).':'.gmdate('H:i',0).':'.date('U',0); date_default_timezone_set($old);"
        "UTC:Asia/Tokyo:Asia/Tokyo:09:00:00:00:0")
       ("<?php $old=date_default_timezone_get(); date_default_timezone_set('Asia/Tokyo'); $prev=ini_set('date.timezone','UTC'); echo $prev.':'.date_default_timezone_get().':'.ini_get('date.timezone'); date_default_timezone_set($old);"
        "Asia/Tokyo:UTC:UTC")
       ("<?php $old=date_default_timezone_get(); date_default_timezone_set('UTC'); echo (date_default_timezone_set('No/Such_Zone')?'true':'false').':'.date_default_timezone_get(); date_default_timezone_set($old);"
        "false:UTC")
       ("<?php $old=date_default_timezone_get(); date_default_timezone_set('Asia/Tokyo'); echo strtotime('1970-01-01 09:00:00').':'.mktime(18,0,0,1,1,1970).':'.date('Y-m-d H:i',0); date_default_timezone_set($old);"
        "0:32400:1970-01-01 09:00"))
      "php-e2e-date-default-timezone-and-ini: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-e2e-heredoc-nowdoc"
    (expect
      (%php-run-capture (format nil "<?php $n=\"Bob\"; echo <<<EOT~%Hi $n~%EOT;~%"))
      :to-equal
      "Hi Bob")
    (expect
      (%php-run-capture
        (format nil "<?php $a=\"X\";$b=\"Y\"; echo <<<EOT~%$a-$b~%EOT;~%"))
      :to-equal
      "X-Y")
    (expect
      (%php-run-capture
        (format nil "<?php $n=\"Bob\"; echo <<<EOT~%Hi {$n}!~%EOT;~%"))
      :to-equal
      "Hi Bob!")
    (expect
      (%php-run-capture
        (format nil "<?php $n=\"Z\"; echo <<<EOT~%line1~%val=$n~%EOT;~%"))
      :to-equal
      (format nil "line1~%val=Z"))
    (expect
      (%php-run-capture (format nil "<?php $n=\"Q\"; echo <<<\"EOT\"~%v=$n~%EOT;~%"))
      :to-equal
      "v=Q")
    (expect
      (%php-run-capture (format nil "<?php $n=\"Bob\"; echo <<<'EOT'~%Hi $n~%EOT;~%"))
      :to-equal
      "Hi $n"))
  (it-sequential-each
      (("<?php list($a,$b)=[1,2]; echo $a+$b;" "3")
       ("<?php list($a,$b,$c)=[10,20,30]; echo $a+$b+$c;" "60")
       ("<?php function pair(){return [4,9];} list($x,$y)=pair(); echo $x.'-'.$y;"
        "4-9")
       ("<?php list($n,$a)=['Bob',30]; echo $n.':'.$a;" "Bob:30")
       ("<?php [$a,$b]=[1,2]; echo $a.','.$b;" "1,2")
       ("<?php $a=1;$b=2; [$a,$b]=[$b,$a]; echo $a.','.$b;" "2,1"))
      "php-e2e-list-destructuring: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php [[$a,$b],$c]=[[1,2],3]; echo $a+$b+$c;" "6")
       ("<?php list(list($a,$b),$c)=[[1,2],3]; echo $a+$b+$c;" "6")
       ("<?php ['x'=>$a,'y'=>$b]=['x'=>1,'y'=>2]; echo $a+$b;" "3")
       ("<?php ['y'=>$a,'x'=>$b]=['x'=>1,'y'=>2]; echo $a-$b;" "1")
       ("<?php [['k'=>$a],$b]=[['k'=>9],3]; echo $a.','.$b;" "9,3"))
      "php-e2e-list-destructuring-nested-keyed: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=['k'=>5]; echo \"v={$a['k']}\";" "v=5")
       ("<?php $a=['x'=>['y'=>9]]; echo \"n={$a['x']['y']}\";" "n=9")
       ("<?php class C{ function g(){ return 42; } } $o=new C(); echo \"m={$o->g()}\";"
        "m=42")
       ("<?php $n='Bob'; $a=['age'=>30]; echo \"Hi $n, age {$a['age']}!\";"
        "Hi Bob, age 30!")
       ("<?php $n='Bob'; echo \"Hi $n!\";" "Hi Bob!")
       ("<?php $n='Bob'; echo \"Hi {$n}!\";" "Hi Bob!"))
      "php-e2e-complex-string-interpolation: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function f($x){ return $x == 4; } echo f(4);" "1")
       ("<?php function f($x){ return $x == 4; } echo f(3);" "")
       ("<?php function f($x){ return $x != 4; } echo f(3);" "1")
       ("<?php function f($x){ return $x % 2 == 0; } echo f(4);" "1"))
      "php-e2e-equality-operators: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a='5'; if ($a == 5) { echo 'loose'; }" "loose")
       ("<?php $a='5'; if ($a === 5) { echo 'x'; } else { echo 'strictfail'; }"
        "strictfail"))
      "php-e2e-equality-type-juggling: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo true;" "1")
       ("<?php echo false;" "")
       ("<?php echo true . 'X';" "1X")
       ("<?php echo false . 'X';" "X")
       ("<?php echo (5 == 5);" "1")
       ("<?php echo 1,2,3;" "123"))
      "php-e2e-echo-boolean-php-semantics: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo (true && true) ? 'T':'F';" "T")
       ("<?php echo (true && false) ? 'T':'F';" "F")
       ("<?php echo (false || true) ? 'T':'F';" "T")
       ("<?php echo (false || false) ? 'T':'F';" "F")
       ("<?php echo !false ? 'T':'F';" "T")
       ("<?php echo !5 ? 'T':'F';" "F")
       ("<?php echo true && true;" "1"))
      "php-e2e-logical-operators: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=1; $b=2; if ($a && $b) { echo 'both'; }" "both")
       ("<?php $x=5; if ($x > 0 && $x < 10) { echo 'mid'; }" "mid")
       ("<?php $a=true; $b=false; if (!$b && $a) { echo 'ok'; }" "ok"))
      "php-e2e-logical-in-conditions: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-e2e-logical-short-circuit"
    (expect
      (%php-run-capture
        "<?php function boom(){ return 1/0; } $x=false; echo ($x && boom()) ? 'T':'F';")
      :to-equal
      "F"))
  (it-sequential-each
      (("<?php function g($x=7){ return $x; } echo g();" "7")
       ("<?php function g($x=7){ return $x; } echo g(3);" "3")
       ("<?php function g($s='hi'){ return $s; } echo g();" "hi")
       ("<?php function f($a,$b=10){ return $a+$b; } echo f(5);" "15")
       ("<?php function f($a,$b=10){ return $a+$b; } echo f(5,2);" "7")
       ("<?php function f($a=1,$b=2,$c=3){ return $a+$b+$c; } echo f();" "6")
       ("<?php function f($a=1,$b=2,$c=3){ return $a+$b+$c; } echo f(10);" "15"))
      "php-e2e-default-arguments: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function join3($a,$b,$c){ return $a.$b.$c; } echo join3(c:'C', a:'A', b:'B');"
        "ABC")
       ("<?php function f($a='A',$b='B',$c='C'){ return $a.$b.$c; } echo f(c:'C', b:2);"
        "A2C")
       ("<?php function f($a='A',$b='B',$c='C'){ return $a.$b.$c; } echo f('X', c:'C');"
        "XBC")
       ("<?php function join3($a,$b,$c){ return $a.$b.$c; } echo join3(...['A'], b:'B', c:'C');"
        "ABC")
       ("<?php function join3($a,$b,$c){ return $a.$b.$c; } echo join3(...['A','B'], c:'C');"
        "ABC")
       ("<?php function f($a='A',$b='B',$c='C'){ return $a.$b.$c; } echo f(...['X'], c:'C');"
        "XBC")
       ("<?php class C{ function join3($a,$b,$c){ return $a.$b.$c; } } $c=new C(); echo $c->join3(c:'C', a:'A', b:'B');"
        "ABC")
       ("<?php class C{ function join3($a,$b,$c){ return $a.$b.$c; } } $c=new C(); echo $c?->join3(c:'C', a:'A', b:'B');"
        "ABC")
       ("<?php class C{ static function join3($a,$b,$c){ return $a.$b.$c; } } echo C::join3(c:'C', a:'A', b:'B');"
        "ABC")
       ("<?php class C{ function join3($a,$b,$c){ return $a.$b.$c; } } $c=new C(); echo $c->join3(...['A'], b:'B', c:'C');"
        "ABC"))
      "php-e2e-named-arguments: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $f=function($x=9){ return $x; }; echo $f();" "9")
       ("<?php $f=function($x=9){ return $x; }; echo $f(4);" "4")
       ("<?php $f=fn($x=8)=>$x*2; echo $f();" "16")
       ("<?php class C{ function m($x=5){ return $x; } } $c=new C(); echo $c->m();"
        "5")
       ("<?php class C{ function m($x=5){ return $x; } } $c=new C(); echo $c->m(20);"
        "20"))
      "php-e2e-default-arguments-all-callable-forms: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function s(...$n){ return array_sum($n); } echo s(1,2,3,4);" "10")
       ("<?php function s(...$n){ return count($n); } echo s(1,2,3,4);" "4")
       ("<?php function s(...$n){ return count($n); } echo s();" "0")
       ("<?php function f($a,...$rest){ return $a.':'.count($rest); } echo f('x',1,2,3);"
        "x:3")
       ("<?php function j(...$xs){ $r=''; foreach($xs as $x){ $r.=$x; } return $r; } echo j('a','b','c');"
        "abc"))
      "php-e2e-variadic-parameters: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $s=function(...$n){ return array_sum($n); }; echo $s(1,2,3);" "6")
       ("<?php $s=fn(...$n)=>array_sum($n); echo $s(5,5,5);" "15"))
      "php-e2e-variadic-all-callable-forms: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function add($a,$b){ return $a+$b; } $args=[2,3]; echo add(...$args);"
        "5")
       ("<?php function add3($a,$b,$c){ return $a+$b+$c; } $x=[1,2,3]; echo add3(...$x);"
        "6")
       ("<?php function f($a,$b,$c){ return $a.$b.$c; } $r=['y','z']; echo f('x',...$r);"
        "xyz")
       ("<?php $a=[3,1,2]; echo max(...$a);" "3")
       ("<?php $a=[3,1,2]; echo min(...$a);" "1"))
      "php-e2e-spread-call: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function j($a,$b,$c){ return $a.$b.$c; } $args=['a','b']; echo j(...$args, c:'c');"
        "abc")
       ("<?php function j($a,$b='x',$c='z'){ return $a.$b.$c; } $args=['a']; echo j(...$args, c:'c');"
        "axc"))
      "php-e2e-named-args-after-dynamic-spread: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function s(...$n){ return array_sum($n); } $a=[10,20,30]; echo s(...$a);"
        "60")
       ("<?php $f=function($a,$b){ return $a*$b; }; $args=[4,5]; echo $f(...$args);"
        "20"))
      "php-e2e-spread-composes-with-variadic-and-closures: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $s=0; for($i=0;$i<6;$i++){ if($i%2)continue; $s+=$i; } echo $s;"
        "6")
       ("<?php $s=0; for($i=0;$i<10;$i++){ if($i==5)break; if($i%2)continue; $s+=$i; } echo $s;"
        "6")
       ("<?php $s=0; for($i=0;$i<3;$i++){ for($j=0;$j<3;$j++){ if($j==1)continue; $s++; } } echo $s;"
        "6"))
      "php-e2e-for-loop-continue: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $s=0; for($i=1;$i<=4;$i++){ $s+=$i; } echo $s;" "10")
       ("<?php $s=0; for($i=0;$i<10;$i++){ if($i==3)break; $s+=$i; } echo $s;"
        "3")
       ("<?php $s=''; for($i=3;$i>0;$i--){ $s.=$i; } echo $s;" "321"))
      "php-e2e-for-loop-basics: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-parser-cli-compile-path-for-php-files"
    (let* ((tmp-dir (uiop:temporary-directory))
           (input (merge-pathnames "cl-cc-php-compile-gap.php" tmp-dir))
           (output (merge-pathnames "cl-cc-php-compile-gap" tmp-dir)))
      (with-open-file (stream input :direction :output :if-exists :supersede)
        (write-line "<?php echo match($x) { 1 => 'one', default => 'other' };" stream))
      (let ((result (cl-cc/pipeline::compile-file-to-native input :output-file output)))
        (expect result :to-equal output)
        (expect (probe-file output) :to-be-truthy))))
  (it-sequential
    "php-runtime-expression-operator-helpers"
    (expect (= 3 (cl-cc/php:%php-modulo 7 4)) :to-be-truthy)
    (expect (= -1 (cl-cc/php:%php-modulo -7 3)) :to-be-truthy)
    (expect (= 8 (cl-cc/php:%php-shift-left 1 3)) :to-be-truthy)
    (expect (= -4 (cl-cc/php:%php-shift-right -8 1)) :to-be-truthy)
    (expect (= -1 (cl-cc/php:%php-spaceship 1 2)) :to-be-truthy)
    (expect (= 0 (cl-cc/php:%php-spaceship "2" 2)) :to-be-truthy)
    (expect (= 2 (cl-cc/php:%php-bitwise-and 6 3)) :to-be-truthy)
    (expect (= 7 (cl-cc/php:%php-bitwise-or 6 3)) :to-be-truthy)
    (expect (= 5 (cl-cc/php:%php-bitwise-xor 6 3)) :to-be-truthy)
    (expect (= -2 (cl-cc/php:%php-bitwise-not 1)) :to-be-truthy))
  (it-sequential
    "php-compile-expression-operators"
    (let ((result
          (cl-cc/compile:compile-string
            "<?php $a = 2 ** 3 ** 2; $b = 7 % 4; $c = 1 << 3; $d = 8 >> 1; $e = 1 <=> 2; $f = 6 & 3; $g = 6 ^ 3; $h = 4 | 1; $i = ~1; $j = 1 + 2 . 3;"
            :target
            :vm
            :language
            :php)))
      (expect (typep result 'cl-cc/compile:compilation-result) :to-be-truthy)))
  (it-sequential-each
      (("<?php $x=2; echo match($x){1=>'a',2=>'b'};" "b")
       ("<?php $x=2; echo match($x){1,2=>'low',3=>'hi'};" "low")
       ("<?php $x=3; echo match($x){1,2=>'low',3=>'hi'};" "hi")
       ("<?php $x=5; echo match(true){$x>3=>'big',default=>'small'};" "big")
       ("<?php $x=1; echo match(true){$x>3=>'big',default=>'small'};" "small")
       ("<?php echo gettype(5>3);" "boolean")
       ("<?php echo gettype(2<1);" "boolean")
       ("<?php echo (5>3)===true ? 'T':'n';" "T")
       ("<?php echo gettype(true);" "boolean")
       ("<?php echo 'apple'<'banana' ? 'y':'n';" "y")
       ("<?php $s=0; for($i=0;$i<4;$i++){$s+=$i;} echo $s;" "6")
       ("<?php echo 1<=>2;" "-1"))
      "php-e2e-match-and-relational-booleans: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=null; $a ??= 'x'; echo $a;" "x")
       ("<?php $a='keep'; $a ??= 'x'; echo $a;" "keep")
       ("<?php $a=false; $a ??= 'x'; echo $a===false?'F':'o';" "F")
       ("<?php $a=0; $a ??= 'x'; echo $a;" "0")
       ("<?php class C{public $x;} $o=new C(); $o->x ??= 'y'; echo $o->x;" "y")
       ("<?php class C{public $x=5;} $o=new C(); $o->x ??= 'y'; echo $o->x;" "5")
       ("<?php $a=[]; $a['k'] ??= 'v'; echo $a['k'];" "v")
       ("<?php $a=['k'=>3]; $a['k'] ??= 'v'; echo $a['k'];" "3"))
      "php-e2e-nullish-coalescing-assignment: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a += 3; echo $a;" "3")
       ("<?php $a -= 3; echo $a;" "-3")
       ("<?php $a *= 5; echo $a;" "0")
       ("<?php $s .= 'hi'; echo $s;" "hi")
       ("<?php $a ??= 'y'; echo $a;" "y")
       ("<?php $a=5; $a += 3; echo $a;" "8")
       ("<?php $a='7'; $a += '3'; echo $a;" "10")
       ("<?php $a='10'; $a -= true; $a -= '1'; echo $a;" "8")
       ("<?php $a='3'; $a *= '2'; echo $a;" "6")
       ("<?php $s='x'; $s .= 'y'; echo $s;" "xy"))
      "php-e2e-compound-assign-undefined-var: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo null + 3;" "3")
       ("<?php echo '5' + 3;" "8")
       ("<?php echo '4' * '2';" "8")
       ("<?php echo '1.5' + 1;" "2.5")
       ("<?php echo true + 1;" "2")
       ("<?php echo 2 - -3;" "5")
       ("<?php echo +'7';" "7")
       ("<?php echo -'7';" "-7")
       ("<?php echo -null;" "0")
       ("<?php echo -true;" "-1")
       ("<?php echo 2 + 3;" "5")
       ("<?php echo 2 + 3 * 4;" "14")
       ("<?php $a=10; $a -= 3; echo $a;" "7")
       ("<?php $s=0; for($i=1;$i<=4;$i++){$s+=$i;} echo $s;" "10"))
      "php-e2e-arithmetic-operand-coercion: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo 1.5 * 2;" "3")
       ("<?php echo 1.5 + 0.25;" "1.75")
       ("<?php echo 3.14;" "3.14")
       ("<?php echo 6.0;" "6")
       ("<?php echo 1000000.0;" "1000000")
       ("<?php echo 10 / 4;" "2.5")
       ("<?php echo 10 / 2;" "5")
       ("<?php echo 'x=' . 1.5;" "x=1.5")
       ("<?php $f=2.5; echo \"v=$f\";" "v=2.5")
       ("<?php echo sqrt(2);" "1.4142135623731")
       ("<?php echo sqrt(4);" "2"))
      "php-e2e-float-stringification: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php function sq($x){return $x*$x;} $f=sq(...); echo $f(5);" "25")
       ("<?php function sub($a,$b){return $a-$b;} $f=sub(...); echo $f(10,3);"
        "7")
       ("<?php function dbl($x){return $x*2;} $f=dbl(...); echo array_sum(array_map($f,[1,2,3]));"
        "12")
       ("<?php $f=strlen(...); echo $f('hello');" "5")
       ("<?php function sq($x){return $x*$x;} echo array_sum(array_map(sq(...),[1,2,3]));"
        "14")
       ("<?php function sq($x){return $x*$x;} echo sq(5);" "25")
       ("<?php function s(...$n){return array_sum($n);} $a=[1,2]; echo s(...$a);"
        "3"))
      "php-e2e-first-class-callable: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected)))
