(add-to-load-path (string-append (dirname (current-filename)) "/.."))

(use-modules (srfi srfi-9)
             (srfi srfi-64)
             (oop goops)
             (canary app))

(test-begin "access")

(test-equal "first list" 'a (first '(a b c)))
(test-equal "second list" 'b (second '(a b c)))
(test-equal "third list"  'c (third  '(a b c)))
(test-equal "rest list"   '(b c) (rest '(a b c)))
(test-equal "at list"     'c (at '(a b c) 2))
(test-equal "tail-from list" '(c d) (tail-from '(a b c d) 2))
(test-equal "rest dotted pair" 20 (rest '(10 . 20)))

(test-equal "first vector" 'a (first #(a b c)))
(test-equal "third vector" 'c (third #(a b c)))
(test-equal "tail-from vector" #(c d) (tail-from #(a b c d) 2))

(define-record-type <pt>
  (mk-pt x y) pt? (x pt-x) (y pt-y))

(test-equal "first record"  10 (first  (mk-pt 10 20)))
(test-equal "second record" 20 (second (mk-pt 10 20)))

(define-class <pos> ()
  (x #:init-keyword #:x)
  (y #:init-keyword #:y)
  (z #:init-keyword #:z))

(let ((p (make <pos> #:x 1 #:y 2 #:z 3)))
  (test-equal "first goops"  1 (first  p))
  (test-equal "second goops" 2 (second p))
  (test-equal "third goops"  3 (third  p))
  (test-equal "rest goops"   '(2 3) (rest p))
  (test-equal "at goops"     3 (at p 2)))

(define-positions (head 0) (mid 1) (tail-elt 2))
(test-equal "macro head"     'a (head '(a b c)))
(test-equal "macro mid"      'b (mid  '(a b c)))
(test-equal "macro tail-elt" 'c (tail-elt '(a b c)))

(test-end "access")
