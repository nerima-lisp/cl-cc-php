;;;; parser-class-e2e-test.lisp — src/parser-class.lisp — classes, statics, inheritance, SPL, end to
;;;; end.

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

  (it-sequential
    "php-e2e-trait-method-is-actually-callable"
    ;; Every existing trait e2e test before this used EMPTY traits and only checked
    ;; class_uses() reflection (which does work — trait NAMES are tracked). None ever
    ;; called an actual trait method, which is the entire point of a trait — and the most
    ;; basic possible case (one trait, one method, no conflicts) previously failed outright
    ;; with a CLOS "slot is missing" error: `use Greetable;` produced only an internal
    ;; :PHP-TRAIT-USE marker slot-def that class lowering never acted on. Fixed by
    ;; %PHP-MERGE-TRAIT-MEMBERS (src/parser-trait.lisp), which replaces that marker with
    ;; the used traits' actual member slot-defs before the class's AST-DEFCLASS is built.
    (expect (%php-run-capture
             "<?php trait Greetable { function greet() { return 'hi'; } } class C { use Greetable; } $o = new C(); echo $o->greet();")
            :to-equal "hi"))

  (it-sequential
    "php-e2e-trait-method-instead-of-property-still-works-when-mixed"
    ;; A trait can also declare properties, not just methods — %PHP-MERGE-TRAIT-MEMBERS
    ;; copies every member uniformly, not just method-shaped slot-defs.
    (expect (%php-run-capture
             "<?php trait HasName { public $name = 'anon'; function label() { return 'name:'.$this->name; } }
class P { use HasName; }
$p = new P(); echo $p->label();")
            :to-equal "name:anon"))

  (it-sequential
    "php-e2e-two-non-conflicting-traits-both-merge-in"
    (expect (%php-run-capture
             "<?php trait A { function a() { return 'a'; } } trait B { function b() { return 'b'; } }
class C { use A, B; }
$c = new C(); echo $c->a().$c->b();")
            :to-equal "ab"))

  (it-sequential
    "php-e2e-conflicting-trait-methods-resolved-by-insteadof"
    (expect (%php-run-capture
             "<?php trait A { function hello() { return 'A'; } } trait B { function hello() { return 'B'; } }
class C { use A, B { A::hello insteadof B; } }
$c = new C(); echo $c->hello();")
            :to-equal "A"))

  (it-sequential
    "conflicting trait methods with no insteadof clause report a clear error
instead of silently picking one trait's version"
    ;; Real PHP treats this as a fatal "has not been applied, because there are
    ;; collisions" compile error — %PHP-MERGE-TRAIT-MEMBERS matches that rather than
    ;; letting whichever trait happens to be listed first silently win.
    (let ((condition
            (handler-case
                (progn (%php-run-capture
                        "<?php trait A { function hello() { return 'A'; } } trait B { function hello() { return 'B'; } }
class C { use A, B; }
$c = new C(); echo $c->hello();")
                       nil)
              (error (e) e))))
      (expect condition :to-be-truthy)
      (expect (search "more than one" (princ-to-string condition)) :to-be-truthy)))

  (it-sequential
    "php-e2e-trait-as-alias-adds-a-new-name-without-removing-the-original"
    ;; `TraitA::method as alias;' is purely additive in real PHP: the alias becomes an
    ;; extra name for the same method body, and the original name stays callable too.
    (expect (%php-run-capture
             "<?php trait A { function hello() { return 'A'; } } class C { use A { A::hello as hi; } }
$c = new C(); echo $c->hello().'-'.$c->hi();")
            :to-equal "A-A"))

  (it-sequential
    "php-e2e-trait-as-visibility-only-change-does-not-break-the-method"
    ;; `method as protected;' (no rename) changes only the merged member's visibility —
    ;; not tested here is whether that visibility is actually enforced against external
    ;; callers, since this runtime's PHP visibility enforcement is a separate mechanism
    ;; this investigation did not verify; what this confirms is that the alias
    ;; visibility-only path does not corrupt or remove the member itself.
    (expect (%php-run-capture
             "<?php trait A { function hello() { return 'A'; } } class C { use A { hello as protected; } function call() { return $this->hello(); } }
$c = new C(); echo $c->call();")
            :to-equal "A"))

  (it-sequential
    "php-e2e-interface-constant-is-accessible-through-an-implementing-class"
    ;; t/parser-interface-test.lisp's interface-constant tests only check the parser's raw
    ;; AST shape (zero %php-run-capture calls in that whole file) — this is the first check
    ;; that a class implementing an interface can actually read a constant it declares.
    (expect (%php-run-capture
             "<?php interface HasVersion { const VERSION = '1.0'; } class Impl implements HasVersion {} echo Impl::VERSION;")
            :to-equal "1.0"))

  (it-sequential
    "php-e2e-abstract-class-basics"
    ;; No test anywhere in this suite exercised the class-level `abstract' modifier before
    ;; this (only abstract METHODS inside interfaces/traits). Confirms the modifier at
    ;; least parses and a concrete subclass still works; does NOT assert that directly
    ;; instantiating the abstract class itself is rejected — see the next test for that,
    ;; kept separate since it may reveal an actual gap rather than just missing coverage.
    (expect (%php-run-capture
             "<?php abstract class Shape { abstract function area(): float; function describe(): string { return 'area='.$this->area(); } }
class Square extends Shape { function __construct(private float $side) {} function area(): float { return $this->side * $this->side; } }
$s = new Square(4); echo $s->describe();")
            :to-equal "area=16"))

  (it-sequential
    "instantiating an abstract class directly is currently NOT rejected —
unlike real PHP's fatal \"Cannot instantiate abstract class\" error"
    ;; The `abstract class Foo {...}' PARSING gap fixed just above this test made this
    ;; visible: an earlier version of this same test passed for the wrong reason — the
    ;; parse error the missing :ABSTRACT statement parser caused masked the fact that,
    ;; once parsing succeeds, `new Shape()' on an abstract class is not actually
    ;; rejected at all. Nothing currently tracks "is this class abstract" as class
    ;; metadata past parsing, and no instantiation-time check exists to consult it —
    ;; a real, separately-scoped gap from the parsing fix, left undone here.
    (expect (%php-run-capture
             "<?php abstract class Shape { abstract function area(): float; } new Shape(); echo 'no error';")
            :to-equal "no error"))

  (it-sequential
    "does an enum using a trait actually get the trait's methods?"
    ;; t/parser-class-test.lisp's "php-parser-enum-implements-methods-traits-and-constants"
    ;; combines `enum ... { use HasLabels; ... }' but only checks the raw parsed AST shape via
    ;; %PHP-FIRST, never compiles or runs anything — the exact same "looks tested, never
    ;; exercised end-to-end" pattern that hid the class-trait bug fixed earlier in this file.
    ;; %PHP-MERGE-ALL-TRAIT-MEMBERS only merges into :PHP-KIND :CLASS AST-DEFCLASS nodes (see
    ;; its docstring), not :ENUM ones — this checks whether that gap is real.
    (expect (%php-run-capture
             "<?php trait Greetable { function greet() { return 'hi'; } } enum S { use Greetable; case A; } echo S::A->greet();")
            :to-equal "hi"))

  (it-sequential
    "an abstract class using a trait, and a concrete subclass of it, both get
the trait's methods"
    ;; Checking a plausible combination of two things fixed independently this session
    ;; (abstract-class parsing, trait-method merging) for the same kind of interaction bug
    ;; the enum+trait case had.
    (expect (%php-run-capture
             "<?php trait Greetable { function greet() { return 'hi'; } }
abstract class Base { use Greetable; abstract function extra(): string; }
class Impl extends Base { function extra(): string { return 'x'; } }
$o = new Impl(); echo $o->greet().$o->extra();")
            :to-equal "hix"))

  (it-sequential
    "php-e2e-readonly-property-can-be-set-once-during-construction"
    ;; No e2e test anywhere in this suite exercised `readonly' at all before this —
    ;; only parser-level AST-shape tests confirming the modifier is captured.
    (expect (%php-run-capture
             "<?php class Point { public function __construct(public readonly int $x) {} }
$p = new Point(5); echo $p->x;")
            :to-equal "5"))

  (it-sequential
    "reassigning a readonly property after construction is currently NOT
rejected — unlike real PHP's fatal \"Cannot modify readonly property\" error"
    ;; Same class of gap as abstract-class instantiation above: the modifier parses and is
    ;; captured as AST metadata (see t/parser-class-test.lisp), but nothing enforces it at
    ;; property-write time. Documented via a test asserting the current, unenforced
    ;; behavior rather than implemented — enforcing this needs the property-write lowering
    ;; to check readonly-ness and the object's own already-initialized-or-not state, which
    ;; this investigation did not trace.
    (expect (%php-run-capture
             "<?php class Point { public function __construct(public readonly int $x) {} }
$p = new Point(5); $p->x = 99; echo $p->x;")
            :to-equal "99"))

  (it-sequential
    "php-e2e-final-class-basics"
    ;; `final class Foo {...}' had no registered top-level statement parser at all before
    ;; this — the same gap `abstract class` had, fixed the same way. No test anywhere
    ;; exercised the class-level `final' modifier before this.
    (expect (%php-run-capture
             "<?php final class Sealed { function greet() { return 'hi'; } } $o = new Sealed(); echo $o->greet();")
            :to-equal "hi"))

  (it-sequential
    "extending a final class is currently NOT rejected — unlike real PHP's
fatal \"Cannot extend final class\" error"
    ;; Same class of gap as abstract-class instantiation and readonly reassignment
    ;; elsewhere in this file: the modifier now parses, but nothing tracks "is this class
    ;; final" past parsing to reject an extends of it.
    (expect (%php-run-capture
             "<?php final class Sealed { function greet() { return 'hi'; } } class Broken extends Sealed {} $o = new Broken(); echo $o->greet();")
            :to-equal "hi"))

  (it-sequential "final method: parses and runs like an ordinary method"
    ;; :final is already in %php-parse-visibility-modifiers's accepted modifier list
    ;; alongside :abstract/:readonly, so a member-level `final function` is consumed as
    ;; an ordinary modifier before the :function dispatch -- no separate grammar entry
    ;; needed (unlike `final class`, which required its own statement-level parser).
    (expect (%php-run-capture
             "<?php class Base { final function seal() { return 'sealed'; } } $o = new Base(); echo $o->seal();")
            :to-equal "sealed"))

  (it-sequential "final method: overriding in a subclass is not rejected"
    ;; Same class of gap as final-class extension and abstract-instantiation elsewhere
    ;; in this file: the modifier parses and is discarded, but nothing tracks "is this
    ;; method final" past parsing to reject an override in a subclass.
    (expect (%php-run-capture
             "<?php class Base { final function seal() { return 'A'; } } class Sub extends Base { function seal() { return 'B'; } } $o = new Sub(); echo $o->seal();")
            :to-equal "B"))

  )
