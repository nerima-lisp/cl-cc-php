(in-package :cl-cc-php/test)

(describe "PHP compile e2e: objects"


  (it-sequential-each
      (("<?php class M{ static function sq($x){ return $x*$x; } } echo M::sq(5);"
        "25")
       ("<?php class C{ static $n=5; } echo C::$n;"
        "5")
       ("<?php class C{ static $n=1; } C::$n=7; echo C::$n;"
        "7")
       ("<?php class C{ static $n=2; } C::$n += 5; echo C::$n;"
        "7")
       ("<?php class C{ static $n=1; } echo C::$n++; echo ':'.C::$n;"
        "1:2")
       ("<?php class C{ static $n=1; } echo ++C::$n; echo ':'.C::$n;"
        "2:2")
       ("<?php class C{ static $n=1; static function inc(){ self::$n += 2; return self::$n; } } echo C::inc().':'.C::$n;"
        "3:3")
       ("<?php class C{ const PI=3; static $n=5; } echo C::PI.'|'.C::$n;"
        "3|5")
       ("<?php class U{ static function inc($x){ return $x+1; } static function dbl($x){ return $x*2; } } echo U::inc(U::dbl(10));"
        "21"))
      "php-e2e-static-members: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ static function f(){ return self::g(); } static function g(){ return 9; } } echo C::f();"
        "9")
       ("<?php class C{ static function f(){ return static::g(); } static function g(){ return 7; } } echo C::f();"
        "7")
       ("<?php class C{ const X=42; static function get(){ return self::X; } } echo C::get();"
        "42")
       ("<?php class F{ static function fac($n){ return $n<=1?1:$n*F::fac($n-1); } } echo F::fac(5);"
        "120")
       ("<?php class F{ static function fac($n){ return $n<=1?1:$n*self::fac($n-1); } } echo F::fac(6);"
        "720")
       ("<?php class A{ static function who(){ return 1; } } class B extends A{ static function who2(){ return parent::who()+10; } } echo B::who2();"
        "11")
       ("<?php class K{ public $base=100; static function tag(){ return 9; } function show(){ return $this->base+K::tag(); } } $o=new K(); echo $o->show();"
        "109"))
      "php-e2e-self-static-parent: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ function __construct(){ echo 'made'; } } $o=new C();"
        "made")
       ("<?php class C{ public $x; function __construct($v){ $this->x=$v; } } $o=new C(9); echo $o->x;"
        "9")
       ("<?php class P{ public $n; public $a; function __construct($n,$a){ $this->n=$n; $this->a=$a; } } $p=new P('Bob',30); echo $p->n.':'.$p->a;"
        "Bob:30")
       ("<?php class C{ public $x; function __construct($v){ $this->x=$v; } function dbl(){ return $this->x*2; } } $o=new C(5); echo $o->dbl();"
        "10")
       ("<?php class C{ public $x=5; } $o=new C(); echo $o->x;"
        "5"))
      "php-e2e-constructor: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ public $x=1; } $a=new C(); $b=clone $a; $b->x=9; echo $a->x.':'.$b->x;"
        "1:9")
       ("<?php class C{ public $x; function __construct($x){ $this->x=$x; } function __clone(){ $this->x=$this->x+10; } } $a=new C(4); $b=clone $a; echo $a->x.':'.$b->x;"
        "4:14"))
      "php-e2e-clone-object: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ function __construct(public $x){} } $o=new C(42); echo $o->x;"
        "42")
       ("<?php class P{ function __construct(public $n, public $v){} } $p=new P('hello',99); echo $p->n.':'.$p->v;"
        "hello:99")
       ("<?php class M{ function __construct(public $x, $label){ echo $this->x.':'.$label; } } $o=new M(5,'extra');"
        "5:extra")
       ("<?php class C{ function __construct(public $v){ $this->v=$this->v*2; } } $o=new C(5); echo $o->v;"
        "10"))
      "php-e2e-constructor-promotion: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ public $x=3; function g(){ return $this->x; } } $o=new C(); echo $o->g();"
        "3")
       ("<?php class C{ public $b=10; function add($a){ return $this->b+$a; } } $o=new C(); echo $o->add(5);"
        "15")
       ("<?php class C{ public $n=0; function setN($v){ $this->n=$v; } } $o=new C(); $o->setN(7); echo $o->n;"
        "7")
       ("<?php class C{ public $c=0; function inc(){ $this->c=$this->c+1; return $this->c; } } $o=new C(); $o->inc(); echo $o->inc();"
        "2")
       ("<?php class C{ public $v=1; function get(){ return $this->v; } function me(){ return $this; } } $o=new C(); echo $o->me()->get();"
        "1")
       ("<?php class C{ function g(){ return 42; } } $o=new C(); echo $o->g();"
        "42"))
      "php-e2e-instance-method-this: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{ public $x=7; } $o=new C(); echo $o->x;"
        "7")
       ("<?php class C{ public $x; } $o=new C(); $o->x=5; echo $o->x;"
        "5")
       ("<?php class C{ public $x=7; } $o=new C(); echo \"x={$o->x}\";"
        "x=7")
       ("<?php class C{ public $s='hi'; } $o=new C(); echo $o->s;"
        "hi"))
      "php-e2e-class-property-access: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


(it-sequential "php-runtime-enum-helpers"
  (let* ((class (make-hash-table :test #'eq))
         (draft (cl-cc/php:%php-enum-make-case 'status 'draft 0))
         (published (cl-cc/php:%php-enum-make-case 'status 'published 1)))
    (setf (gethash :__class-slots__ class) '(draft published)
          (gethash 'draft class) draft
          (gethash 'published class) published)
    ;; %php-enum-case-list is the internal CL list; %php-enum-cases (ENUM::cases())
    ;; now returns a PHP array (hash-table) so count()/foreach work.
    (expect (cl-cc/php:%php-enum-case-list class) :to-equal (list draft published))
    (expect (hash-table-p (cl-cc/php:%php-enum-cases class)) :to-be-truthy)
    (expect (= 2 (cl-cc/php:%php-count (cl-cc/php:%php-enum-cases class))) :to-be-truthy)
    (expect (cl-cc/php:%php-enum-from class 1) :to-be published)
    (expect (cl-cc/php:%php-enum-try-from class 99) :to-equal cl-cc/php:+php-null+)
    (expect (= 1 (cl-cc/php:%php-enum-case-value published)) :to-be-truthy)))


(it-sequential "php-compile-enum-static-builtins"
  (let ((result (cl-cc/compile:compile-string
                 "<?php enum Status: int { case Draft = 0; case Published = 1; } $a = Status::Published; $b = Status::from(1); $c = Status::tryFrom(99); $d = Status::cases();"
                 :target :vm
                 :language :php)))
    (expect (typep result 'cl-cc/compile:compilation-result) :to-be-truthy)))


  (it-sequential-each
      (("<?php class C{public $x;} $o=new C(); echo is_null($o->x)?'yes':'no';"
        "yes")
       ("<?php class C{public $x;} $o=new C(); echo $o->x ?? 'def';"
        "def")
       ("<?php class C{public $x=7;} $o=new C(); echo $o->x ?? 'def';"
        "7")
       ("<?php class C{public $s='hi';} $o=new C(); echo $o->s;"
        "hi")
       ("<?php class C{public $x;} $o=new C(); $o->x=9; echo $o->x;"
        "9"))
      "php-e2e-uninitialized-property-null: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{public $x=7;} $o=new C(); unset($o->x); echo is_null($o->x)?'null':'set';"
        "null")
       ("<?php class C{public $x='x';} $o=new C(); unset($o->x); echo $o->x ?? 'D';"
        "D")
       ("<?php class C{public $x=1; public $y=2;} $o=new C(); $a=[9]; unset($a[0], $o->y); echo $o->x.':'.(is_null($o->y)?'null':'set').':'.count($a);"
        "1:null:0"))
      "php-e2e-unset-object-property: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php enum S{case A;} echo S::A->name;"
        "A")
       ("<?php enum S:string{case A='a';case B='b';} echo S::A->value;"
        "a")
       ("<?php enum S:int{case A=10;} echo S::A->value;"
        "10")
       ("<?php enum S{case A;case B;} echo count(S::cases());"
        "2")
       ("<?php enum S{case A;case B;} $n=''; foreach(S::cases() as $c){$n.=$c->name;} echo $n;"
        "AB")
       ("<?php enum S:int{case A=1;case B=2;} echo S::from(2)->name;"
        "B")
       ("<?php enum S:int{case A=1;} echo S::tryFrom(9)===null?'null':'f';"
        "null")
       ("<?php enum S{case A;} echo S::A===S::A?'y':'n';"
        "y")
       ("<?php enum Suit:string{case H='h';case S='s';} $x=Suit::H; echo match($x){Suit::H=>'hearts',Suit::S=>'spades'};"
        "hearts"))
      "php-e2e-enum-name-value-cases: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php enum S{case A; public function label(){return 'L';}} echo S::A->label();"
        "L")
       ("<?php enum S:string{case A='a'; public function up(){return strtoupper($this->value);}} echo S::A->up();"
        "A")
       ("<?php enum Suit{case H;case S; public function color(){return match($this){Suit::H=>'red',Suit::S=>'black'};}} echo Suit::H->color();"
        "red")
       ("<?php enum S{case A; public function add($n){return $n+1;}} echo S::A->add(5);"
        "6")
       ("<?php enum S{case A; public function x(){return 1;}} echo S::A->name;"
        "A")
       ("<?php enum S{case A; const X=5; public function y(){return 2;}} echo S::X;"
        "5"))
      "php-e2e-enum-methods: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php class C{public $x=5;} $o=new C(); echo $o?->x;"
        "5")
       ("<?php class C{public $x=5;} $o=null; echo $o?->x ?? 'def';"
        "def")
       ("<?php class C{function m(){return 7;}} $o=new C(); echo $o?->m();"
        "7")
       ("<?php class C{function m(){return 7;}} $o=null; echo $o?->m() ?? 'n';"
        "n")
       ("<?php class C{public $v=3; function get(){return $this->v;}} $o=new C(); echo $o?->get();"
        "3")
       ("<?php class C{public $n=null;} $o=new C(); echo $o?->n?->x ?? 'none';"
        "none")
       ("<?php class C{public $x;} $o=new C(); echo $o?->x ?? 'wasnull';"
        "wasnull"))
      "php-e2e-nullsafe-operator: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php echo PHP_INT_MAX;"
        "9223372036854775807")
       ("<?php echo PHP_INT_SIZE;"
        "8")
       ("<?php echo round(M_PI,5);"
        "3.14159")
       ("<?php echo PHP_VERSION;"
        "8.5.0")
       ("<?php echo phpversion();"
        "8.5.0")
       ("<?php echo is_nan(NAN) ? '1' : '0';"
        "1")
       ("<?php echo SORT_STRING;"
        "2")
       ("<?php echo PHP_EOL===\"\\n\"?'y':'n';"
        "y")
       ("<?php echo str_pad('5',3,'0',STR_PAD_LEFT);"
        "005")
       ("<?php echo str_pad('5',3,'0',STR_PAD_RIGHT);"
        "500")
       ("<?php echo \\PHP_MAJOR_VERSION;"
        "8")
       ("<?php echo NOT_A_REAL_CONSTANT_XYZ;"
        ""))
      "php-e2e-predefined-constants: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


(it-sequential "php-e2e-predefined-constants-are-not-functions"
  (expect (%php-run-capture
                   "<?php echo function_exists('PHP_EOL')?'present':'absent'; echo ':'; echo function_exists('SORT_STRING')?'present':'absent'; echo ':'; echo function_exists('null')?'present':'absent';") :to-equal "absent:absent:absent"))


  (it-sequential-each
      (("<?php function sq($x){return $x*$x;} echo call_user_func('sq',5);"
        "25")
       ("<?php function add($a,$b){return $a+$b;} echo call_user_func('add',3,4);"
        "7")
       ("<?php echo call_user_func('strtoupper','hi');"
        "HI")
       ("<?php $f=function($n){return $n+100;}; echo call_user_func($f,1);"
        "101")
       ("<?php $g=fn($x)=>$x*3; echo call_user_func($g,7);"
        "21")
       ("<?php function add($a,$b){return $a+$b;} echo call_user_func_array('add',[10,20]);"
        "30")
       ("<?php function sq($x){return $x*$x;} echo call_user_func_array('sq',[6]);"
        "36"))
      "php-e2e-call-user-func: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


(it-sequential "php-e2e-spl-autoload-default-loader-is-absent"
  (expect (%php-run-capture
                   "<?php echo function_exists('spl_autoload')?'present':'absent';") :to-equal "absent"))


(it-sequential "php-e2e-spl-autoload-registry"
  (expect (%php-run-capture
                   "<?php function clcc_loader_a($c){} function clcc_loader_b($c){} spl_autoload_unregister('clcc_loader_a'); spl_autoload_unregister('clcc_loader_b'); echo spl_autoload_register('clcc_loader_a')?'R':'F'; echo spl_autoload_register('clcc_loader_b', true, true)?'P':'F'; $list=spl_autoload_functions(); echo ':'.count($list).':'.$list[0].':'.$list[1]; echo ':'.(spl_autoload_unregister('clcc_loader_a')?'U':'N'); $list=spl_autoload_functions(); $found=''; foreach($list as $fn){$found.=$fn.',';} echo ':'.$found; echo ':'.(spl_autoload_unregister('clcc_loader_a')?'again':'missing'); spl_autoload_unregister('clcc_loader_b');") :to-equal "RP:2:clcc_loader_b:clcc_loader_a:U:clcc_loader_b,:missing"))


  (it-sequential-each
      (("<?php interface ReflIfaceI{} interface ReflIfaceB extends ReflIfaceI{} class ReflImpl implements ReflIfaceB{} $s=''; foreach(class_implements(new ReflImpl()) as $v){$s.=$v;} echo $s;"
        "REFLIFACEBREFLIFACEI")
       ("<?php class ReflBase{} class ReflMid extends ReflBase{} class ReflLeaf extends ReflMid{} $s=''; foreach(class_parents(new ReflLeaf()) as $v){$s.=$v;} echo $s;"
        "REFLMIDREFLBASE")
       ("<?php class ReflStringBase{} class ReflStringChild extends ReflStringBase{} $s=''; foreach(class_parents('ReflStringChild') as $v){$s.=$v;} echo $s;"
        "REFLSTRINGBASE")
       ("<?php trait ReflTraitT{} trait ReflTraitU{} class ReflTraitUser{use ReflTraitT,ReflTraitU;} $s=''; foreach(class_uses(new ReflTraitUser()) as $v){$s.=$v;} echo $s;"
        "REFLTRAITTREFLTRAITU"))
      "php-e2e-class-reflection-builtins: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))


  (it-sequential-each
      (("<?php $s=new SplStack(); $s->push('a'); $s->push('b'); echo $s->pop().$s->top().$s->count().get_class($s); echo method_exists($s,'push')?'Y':'N';"
        "ba1SplStackY")
       ("<?php $q=new SplQueue(); $q->enqueue('a'); $q->enqueue('b'); echo $q->dequeue().$q->bottom().$q->count();"
        "ab1")
       ("<?php $f=new SplFixedArray(2); $f->offsetSet(0,'x'); $f->offsetSet(1,'y'); $f->setSize(3); $f->offsetSet(2,'z'); echo $f->offsetGet(0).$f->offsetGet(1).$f->getSize().$f->offsetGet(2);"
        "xy3z")
       ("<?php $min=new SplMinHeap(); $max=new SplMaxHeap(); foreach([3,1,2] as $v){$min->insert($v);$max->insert($v);} echo $min->extract().$max->extract();"
        "13"))
      "php-e2e-spl-data-structures: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))

  )
