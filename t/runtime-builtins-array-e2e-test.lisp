;;;; runtime-builtins-array-e2e-test.lisp — src/runtime-builtins-array*.lisp — array builtins, end
;;;; to end.

(in-package :cl-cc-php/test)

(describe
  "PHP compile e2e: arrays"
  (it-sequential
    "php-e2e-array-map-closure-callback"
    (expect
      (%php-run-capture
        "<?php $f=function($x){ return $x*10; }; $a=[1,2,3]; $r=array_map($f,$a); echo $r[0].','.$r[1].','.$r[2];")
      :to-equal
      "10,20,30"))
  (it-sequential
    "php-e2e-array-map-preserves-single-array-keys"
    (expect
      (%php-run-capture
        "<?php $r=array_map(null,['x'=>7,'y'=>8]); echo $r['x'].','.$r['y'];")
      :to-equal
      "7,8"))
  (it-sequential
    "php-e2e-array-map-multiple-arrays"
    (expect
      (%php-run-capture
        "<?php $f=function($a,$b){ return $a+$b; }; $r=array_map($f,[1,2,3],[10,20,30]); echo $r[0].','.$r[1].','.$r[2];")
      :to-equal
      "11,22,33"))
  (it-sequential
    "php-e2e-array-map-multiple-arrays-pads-missing-with-null"
    (expect
      (%php-run-capture
        "<?php $f=function($a,$b){ return $a.($b===null?'null':$b); }; $r=array_map($f,[1,2],['a']); echo $r[0].','.$r[1];")
      :to-equal
      "1a,2null"))
  (it-sequential
    "php-e2e-array-map-null-callback-zips"
    (expect
      (%php-run-capture
        "<?php $r=array_map(null,[1,2],['a','b']); echo $r[0][0].$r[0][1].','.$r[1][0].$r[1][1];")
      :to-equal
      "1a,2b"))
  (it-sequential
    "php-e2e-array-map-null-callback-pads-missing-with-null"
    (expect
      (%php-run-capture "<?php $r=array_map(null,[1,2],['a']); echo json_encode($r);")
      :to-equal
      "[[1,\"a\"],[2,null]]"))
  (it-sequential
    "php-e2e-array-slice-preserves-string-keys"
    (expect
      (%php-run-capture
        "<?php $r=array_slice(['x'=>1,5=>2,'y'=>3],0); echo $r['x'].','.$r[0].','.$r['y'];")
      :to-equal
      "1,2,3"))
  (it-sequential
    "php-e2e-array-reverse-preserves-string-keys"
    (expect
      (%php-run-capture
        "<?php $r=array_reverse(['a'=>1,4=>2,'b'=>3]); echo $r['b'].','.$r[0].','.$r['a'];")
      :to-equal
      "3,2,1"))
  (it-sequential-each
      (("<?php $rows=[['id'=>10,'name'=>'Ada'],['id'=>20,'name'=>'Linus']]; $r=array_column($rows,'name','id'); echo $r[10].','.$r[20];"
        "Ada,Linus")
       ("<?php $rows=[['name'=>'Ada'],['id'=>20,'name'=>'Linus']]; $r=array_column($rows,'name','id'); echo $r[0].','.$r[20];"
        "Ada,Linus"))
      "php-e2e-array-column-basic-and-index: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-e2e-array-column-skips-missing-column"
    (expect
      (%php-run-capture
        "<?php $rows=[['name'=>'Ada'],['id'=>20],['name'=>'Grace']]; $r=array_column($rows,'name'); echo count($r).':'.$r[0].':'.$r[1];")
      :to-equal
      "2:Ada:Grace"))
  (it-sequential
    "php-e2e-array-column-null-column-returns-rows"
    (expect
      (%php-run-capture
        "<?php $rows=[['id'=>'a','name'=>'Ada'],['id'=>'b','name'=>'Bob']]; $r=array_column($rows,null,'id'); echo $r['a']['name'].','.$r['b']['name'];")
      :to-equal
      "Ada,Bob"))
  (it-sequential-each
      (("<?php $r=array_keys(['a'=>1,'b'=>'1','c'=>2], 1); echo implode(',', $r);"
        "a,b")
       ("<?php $r=array_keys(['a'=>1,'b'=>'1','c'=>2], 1, true); echo implode(',', $r);"
        "a")
       ("<?php $r=array_keys(['x'=>null,'y'=>0], null, true); echo implode(',', $r);"
        "x"))
      "php-e2e-array-keys-filters-values: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=['s'=>'1','i'=>1]; echo array_search(1,$a).':'.array_search(1,$a,true).':'.(array_search(2,$a)===false?'false':'bad');"
        "s:i:false")
       ("<?php $a=[0=>'needle']; echo array_search('needle',$a)===0?'zero':'bad';"
        "zero"))
      "php-e2e-array-search-strict-and-miss: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-e2e-in-array-strict"
    (expect
      (%php-run-capture
        "<?php $a=['1']; echo (in_array(1,$a)?'loose':'x').':'.(in_array(1,$a,true)?'bad':'strict');")
      :to-equal
      "loose:strict"))
  (it-sequential
    "php-e2e-array-unique-compares-values-as-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_unique(['a'=>0,'b'=>'0','c'=>false,'d'=>null,'e'=>'']));")
      :to-equal
      "{\"a\":0,\"c\":false}"))
  (it-sequential
    "php-e2e-array-count-values-counts-only-ints-and-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_count_values([1,'1',true,null,1.5,'x','x']));")
      :to-equal
      "{\"1\":2,\"x\":2}"))
  (it-sequential
    "php-e2e-array-flip-skips-non-key-values"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_flip(['a'=>'x','b'=>1,'c'=>true,'d'=>null,'e'=>1.5]));")
      :to-equal
      "{\"x\":\"a\",\"1\":\"b\"}"))
  (it-sequential
    "php-e2e-array-diff-compares-values-as-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_values(array_diff([0,'0','x'], ['0'])));")
      :to-equal
      "[\"x\"]"))
  (it-sequential
    "php-e2e-array-intersect-compares-values-as-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_values(array_intersect([0,'0','x'], ['0'])));")
      :to-equal
      "[0,\"0\"]"))
  (it-sequential
    "php-e2e-array-diff-assoc-compares-values-as-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_diff_assoc(['a'=>0,'b'=>'x'], ['a'=>'0']));")
      :to-equal
      "{\"b\":\"x\"}"))
  (it-sequential
    "php-e2e-array-intersect-assoc-compares-values-as-strings"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_intersect_assoc(['a'=>0,'b'=>'x'], ['a'=>'0','b'=>'y']));")
      :to-equal
      "{\"a\":0}"))
  (it-sequential
    "php-e2e-array-diff-assoc-matches-explicit-null"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_diff_assoc(['a'=>null], ['a'=>null]));")
      :to-equal
      "[]"))
  (it-sequential
    "php-e2e-array-intersect-assoc-distinguishes-missing-key-from-null"
    (expect
      (%php-run-capture
        "<?php echo json_encode(array_intersect_assoc(['a'=>null], []));")
      :to-equal
      "[]"))
  (it-sequential
    "php-e2e-array-filter-closure"
    (expect
      (%php-run-capture
        "<?php $f=array_filter([0,1,0,2], function($x){ return $x; }); $s=0; foreach($f as $v){ $s=$s+$v; } echo $s;")
      :to-equal
      "3"))
  (it-sequential-each
      (("<?php $f=array_filter(['a'=>1,'b'=>2,'c'=>3], fn($k)=>$k!='b', ARRAY_FILTER_USE_KEY); echo implode(',', array_keys($f));"
        "a,c")
       ("<?php $f=array_filter(['a'=>1,'b'=>2,'c'=>3], fn($v,$k)=>$v>1 && $k!='a', ARRAY_FILTER_USE_BOTH); echo implode(',', array_keys($f));"
        "b,c")
       ("<?php $f=array_filter(['x'=>0,'y'=>2], null, ARRAY_FILTER_USE_KEY); echo implode(',', $f);"
        "2"))
      "php-e2e-array-filter-mode-flags: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $r=array_pad(['x'=>1,4=>2],4,0); $o=''; foreach($r as $k=>$v){ $o=$o.$k.':'.$v.'|'; } echo $o;"
        "x:1|0:2|1:0|2:0|")
       ("<?php $r=array_pad(['x'=>1,4=>2],-4,0); $o=''; foreach($r as $k=>$v){ $o=$o.$k.':'.$v.'|'; } echo $o;"
        "0:0|1:0|x:1|2:2|")
       ("<?php $r=array_pad(['x'=>1,4=>2],2,0); $o=''; foreach($r as $k=>$v){ $o=$o.$k.':'.$v.'|'; } echo $o;"
        "x:1|0:2|"))
      "php-e2e-array-pad-key-policy: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=[1,2]; $a[]=3; echo count($a);" "3")
       ("<?php $a=[1,2]; $a[]=3; echo $a[2];" "3")
       ("<?php $a=[]; $a[]='x'; $a[]='y'; echo $a[0].$a[1];" "xy")
       ("<?php $a=[]; for($i=0;$i<3;$i++){ $a[]=$i*10; } echo $a[0].$a[1].$a[2];"
        "01020")
       ("<?php $a=['k'=>1]; $a[]=2; echo $a['k'].$a[0];" "12"))
      "php-e2e-array-append: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=[1]; $a[0]=9; echo $a[0];" "9")
       ("<?php $a=[]; $a['x']=5; echo $a['x'];" "5"))
      "php-e2e-array-subscript-set-still-works: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential
    "php-runtime-array-unset-deletes-key"
    (let ((array (cl-cc/php:%php-array (list nil nil "a") (list nil nil "b"))))
      (expect (= 2 (cl-cc/php:%php-count array)) :to-be-truthy)
      (cl-cc/php:%php-array-unset array 0)
      (expect (= 1 (cl-cc/php:%php-count array)) :to-be-truthy)
      (expect (cl-cc/php:%php-array-ref array 0) :to-equal cl-cc/php:+php-null+)
      (expect (cl-cc/php:%php-array-ref array 1) :to-equal "b")))
  (it-sequential-each
      (("<?php $a=[1,2]; $b=[...$a,3]; echo array_sum($b);" "6")
       ("<?php $a=[2,3]; $b=[1,...$a,4]; echo implode(',',$b);" "1,2,3,4")
       ("<?php $a=[1]; $b=[2]; $c=[...$a,...$b]; echo count($c);" "2")
       ("<?php $a=[5,6]; $b=[...$a]; echo array_sum($b);" "11")
       ("<?php $a=['x'=>1]; $b=[...$a,'y'=>2]; echo $b['x'].$b['y'];" "12")
       ("<?php $a=[5=>1, 9=>2]; $b=[...$a]; echo $b[0].$b[1];" "12")
       ("<?php echo array_sum([1,2,3]);" "6")
       ("<?php function s(...$n){return array_sum($n);} $a=[1,2,3]; echo s(...$a);"
        "6"))
      "php-e2e-array-spread: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=[1,2]+[3,4,5]; echo count($a);" "3")
       ("<?php $a=[1,2]+[3,4,5]; echo implode(',',$a);" "1,2,5")
       ("<?php $a=['x'=>1]+['x'=>9,'y'=>2]; echo $a['x'].$a['y'];" "12")
       ("<?php $a=[1=>'a']+[1=>'b',2=>'c']; echo $a[1].$a[2];" "ac")
       ("<?php $a=[]+[1,2]; echo count($a);" "2")
       ("<?php echo 2+3;" "5")
       ("<?php echo '5'+3;" "8")
       ("<?php echo count(array_merge([1,2],[3,4]));" "4"))
      "php-e2e-array-union: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo intdiv(7,2);" "3")
       ("<?php echo intdiv(-7,2);" "-3")
       ("<?php echo intdiv('10','3');" "3")
       ("<?php echo fdiv(10,4);" "2.5")
       ("<?php echo fdiv(6,2);" "3")
       ("<?php echo array_is_list([1,2,3])?'y':'n';" "y")
       ("<?php echo array_is_list([1=>'a',0=>'b'])?'y':'n';" "n")
       ("<?php echo array_is_list(['x'=>1])?'y':'n';" "n")
       ("<?php echo array_is_list([])?'y':'n';" "y"))
      "php-e2e-intdiv-fdiv-array-is-list: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=[3,1,2]; usort($a, fn($x,$y)=>$x-$y); echo implode(',',$a);"
        "1,2,3")
       ("<?php $a=[3,1,2]; usort($a, fn($x,$y)=>$y-$x); echo implode(',',$a);"
        "3,2,1")
       ("<?php function cmp($a,$b){return $a-$b;} $c=[5,2,8,1]; usort($c,'cmp'); echo implode(',',$c);"
        "1,2,5,8")
       ("<?php $d=['banana','apple','cherry']; usort($d,'strcmp'); echo implode(',',$d);"
        "apple,banana,cherry")
       ("<?php $e=['b'=>2,'a'=>1,'c'=>3]; uasort($e, fn($x,$y)=>$x-$y); echo implode(',',array_keys($e));"
        "a,b,c")
       ("<?php $f=['banana'=>1,'apple'=>2]; uksort($f,'strcmp'); echo implode(',',array_keys($f));"
        "apple,banana")
       ("<?php $g=[['k'=>1,'v'=>'a'],['k'=>1,'v'=>'b'],['k'=>0,'v'=>'c']]; usort($g, fn($x,$y)=>$x['k']-$y['k']); echo $g[0]['v'].$g[1]['v'].$g[2]['v'];"
        "cab"))
      "php-e2e-usort-in-place: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=[2,2,1]; $b=['b','a','c']; array_multisort($a, SORT_ASC, SORT_NUMERIC, $b, SORT_ASC, SORT_STRING); echo implode(',',$a).'|'.implode(',',$b);"
        "1,2,2|c,a,b")
       ("<?php $a=[1,10,2]; $b=['a','b','c']; array_multisort($a, SORT_DESC, SORT_NUMERIC, $b); echo implode(',',$a).'|'.implode(',',$b);"
        "10,2,1|b,c,a")
       ("<?php $a=['first'=>2,'third'=>1]; $b=[20,10]; array_multisort($a, $b); echo implode(',',array_keys($a)).'|'.implode(',',array_keys($b));"
        "third,first|0,1"))
      "php-e2e-array-multisort-syncs-arrays-and-flags: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=['10','2','1']; sort($a, SORT_NUMERIC); echo implode(',',$a);"
        "1,2,10")
       ("<?php $a=['10','2','1']; sort($a, SORT_STRING); echo implode(',',$a);"
        "1,10,2")
       ("<?php $a=['10','2','1']; rsort($a, SORT_NUMERIC); echo implode(',',$a); $b=['10','2','1']; rsort($b, SORT_STRING); echo '|'.implode(',',$b);"
        "10,2,1|2,10,1")
       ("<?php $a=['a'=>'10','b'=>'2','c'=>'1']; asort($a, SORT_NUMERIC); echo implode(',',array_keys($a)); $b=['a'=>'10','b'=>'2','c'=>'1']; arsort($b, SORT_STRING); echo '|'.implode(',',array_keys($b));"
        "c,b,a|b,a,c")
       ("<?php $a=[10=>'a',2=>'b',1=>'c']; ksort($a, SORT_STRING); echo implode(',',array_keys($a)); $b=[10=>'a',2=>'b',1=>'c']; krsort($b, SORT_STRING); echo '|'.implode(',',array_keys($b));"
        "1,10,2|2,10,1"))
      "php-e2e-sort-builtins-honor-sort-flags: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php $a=['img10','img2','img1']; natsort($a); echo implode(',',$a);"
        "img1,img2,img10")
       ("<?php $a=['file10.txt','file1.txt','file2.txt']; natsort($a); echo implode(',',$a);"
        "file1.txt,file2.txt,file10.txt")
       ("<?php $a=[3=>'a10',1=>'a2',2=>'a1']; natsort($a); echo implode(',',array_keys($a));"
        "2,1,3")
       ("<?php $a=['IMG10','img2','Img1']; natcasesort($a); echo implode(',',$a);"
        "Img1,img2,IMG10")
       ("<?php echo strnatcmp('img2','img10');" "-1")
       ("<?php echo strnatcmp('img10','img2');" "1")
       ("<?php echo strnatcmp('abc','abc');" "0")
       ("<?php echo strnatcasecmp('IMG2','img10');" "-1"))
      "php-e2e-natsort: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected))
  (it-sequential-each
      (("<?php echo json_encode(array_merge_recursive(['a'=>[1]],['a'=>[2]]));"
        "{\"a\":[1,2]}")
       ("<?php echo json_encode(array_merge_recursive(['a'=>1],['a'=>2]));"
        "{\"a\":[1,2]}")
       ("<?php echo json_encode(array_merge_recursive(['a'=>[1]],['a'=>2]));"
        "{\"a\":[1,2]}")
       ("<?php echo json_encode(array_merge_recursive(['a'=>['x'=>1]],['a'=>['x'=>2]]));"
        "{\"a\":{\"x\":[1,2]}}")
       ("<?php echo json_encode(array_merge_recursive([1,2],[3,4]));"
        "[1,2,3,4]")
       ("<?php echo json_encode(array_merge_recursive(['a'=>1],['b'=>2]));"
        "{\"a\":1,\"b\":2}")
       ("<?php echo json_encode(array_merge_recursive(['a'=>[1]],['a'=>[2]],['a'=>[3]]));"
        "{\"a\":[1,2,3]}"))
      "php-e2e-array-merge-recursive: ~S"
      (source expected)
    (expect (%php-run-capture source) :to-equal expected)))
