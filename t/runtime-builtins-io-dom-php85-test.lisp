;;;; runtime-builtins-io-dom-php85-test.lisp — src/runtime-builtins-io-compat-objects.lisp — the
;;;; PHP 8.5 Dom\Element/Dom\ParentNode/Dom\HTMLDocument classes.
;;;;
;;;; Split out of runtime-builtins-io-objects-php85-test.lisp, which grew back over the 500-line
;;;; limit as later work in this repository's history added more tests to it: these six tests are
;;;; the ones that exercise the Dom\* classes specifically, rather than the broader "PHP 8.5
;;;; runtime objects" grab-bag the parent file covers — the same size-driven, topic-scoped split
;;;; already applied once before to pull runtime-builtins-io-uri-php85-test.lisp out of the same
;;;; parent file.

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 Dom\\* runtime objects"
  (it-sequential
    "PHP 8.5 Dom\\Element method additions execute from PHP source."
    (expect
      (%php-run-capture
        "<?php
$e = new Dom\\Element('div');
$e->insertAdjacentHTML('beforeend', '<span class=\"a\"></span>');
$items = $e->getElementsByClassName('a');
echo get_class($items) . ':' .
     (is_null($e->insertAdjacentHTML('afterbegin', '<b></b>')) ? 'Y' : 'N');
")
      :to-equal
      "Dom\\HTMLCollection:Y"))
  (it-sequential
    "PHP 8.5 Dom\\Element exposes outerHTML and children properties from PHP source."
    (expect
      (%php-run-capture
        "<?php
$e = new Dom\\Element('section');
echo $e->outerHTML . ':' . get_class($e->children) . ':' .
     (property_exists($e, 'outerHTML') ? 'Y' : 'N') . ':' .
     (property_exists($e, 'children') ? 'Y' : 'N') . ':' .
     (interface_exists('Dom\\\\ParentNode') ? 'Y' : 'N') . ':' .
     (class_exists('Dom\\\\HTMLCollection') ? 'Y' : 'N');
")
      :to-equal
      "<section></section>:Dom\\HTMLCollection:Y:Y:Y:Y"))
  (it-sequential
    "PHP 8.5 Dom\\ParentNode children property returns an owner-linked HTMLCollection shim."
    (let* ((element (cl-cc/php::%php-dom-element-new "article"))
           (children (gethash "children" element)))
      (expect (gethash "outerHTML" element) :to-equal "<article></article>")
      (expect (gethash "outerhtml" element) :to-equal "<article></article>")
      (expect (cl-cc/php::%php-get-class children) :to-equal "Dom\\HTMLCollection")
      (expect (gethash "__owner__" children) :to-be element)
      (expect (gethash "__property__" children) :to-equal "children")))
  (it-sequential
    "PHP 8.5 Dom\\HTMLDocument::getElementsByName executes from PHP source."
    (expect
      (%php-run-capture
        "<?php
$doc = new Dom\\HTMLDocument('<form><input name=\"token\"></form>');
$items = $doc->getElementsByName('token');
echo get_class($doc) . ':' . get_class($items) . ':' .
     (method_exists($doc, 'getElementsByName') ? 'Y' : 'N');
")
      :to-equal
      "Dom\\HTMLDocument:Dom\\HTMLCollection:Y"))
  (it-sequential
    "PHP 8.5 Dom\\HTMLDocument::getElementsByName records the query in the collection shim."
    (let* ((doc (cl-cc/php::%php-dom-html-document-new "<input name=\"q\">"))
           (items (cl-cc/php::%php-dom-html-document-get-elements-by-name doc "q")))
      (expect (cl-cc/php::%php-get-class items) :to-equal "Dom\\HTMLCollection")
      (expect (gethash "__name__" items) :to-equal "q")
      (expect (gethash "__owner__" items) :to-be doc)))
  (it-sequential
    "PHP 8.5 Dom\\ParentNode children property is exposed on Dom\\HTMLDocument."
    (expect
      (%php-run-capture
        "<?php
$doc = new Dom\\HTMLDocument('<main></main>');
echo get_class($doc->children) . ':' .
     (property_exists($doc, 'children') ? 'Y' : 'N');
")
      :to-equal
      "Dom\\HTMLCollection:Y")))
