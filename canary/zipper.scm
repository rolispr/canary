;;; zipper.scm --- Functional zipper for sexp navigation

(define-module (canary zipper)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (make-zipper
            zip-node
            zip-down
            zip-up
            zip-left
            zip-right
            zip-replace
            zip-insert-left
            zip-insert-right
            zip-delete
            zip-root
            zip-lefts
            zip-rights
            zip-can-down?
            zip-can-up?
            zip-can-left?
            zip-can-right?
            ;; Paredit operations
            zip-slurp-right
            zip-barf-right
            zip-wrap
            zip-splice
            zip-raise))

;;; Location type - represents cursor position in tree
(define-record-type <loc>
  (make-loc node lefts rights parent)
  loc?
  (node loc-node)       ; current sexp
  (lefts loc-lefts)     ; siblings to left (reversed)
  (rights loc-rights)   ; siblings to right
  (parent loc-parent))  ; parent loc or #f

(define (make-zipper sexp)
  "Create a zipper from root sexp"
  (make-loc sexp '() '() #f))

(define (zip-node loc)
  "Get current node"
  (loc-node loc))

(define (zip-lefts loc)
  "Get left siblings"
  (reverse (loc-lefts loc)))

(define (zip-rights loc)
  "Get right siblings"
  (loc-rights loc))

;;; Navigation predicates
(define (zip-can-down? loc)
  (pair? (loc-node loc)))

(define (zip-can-up? loc)
  (loc-parent loc))

(define (zip-can-left? loc)
  (not (null? (loc-lefts loc))))

(define (zip-can-right? loc)
  (not (null? (loc-rights loc))))

;;; Navigation
(define (zip-down loc)
  "Move down into first child of list"
  (let ((node (loc-node loc)))
    (if (pair? node)
        (match node
          ((first . rest)
           (make-loc first '() rest loc))
          (() #f))
        #f)))

(define (zip-up loc)
  "Move up to parent"
  (let ((parent (loc-parent loc)))
    (if parent
        (let ((new-node (append (reverse (loc-lefts loc))
                               (list (loc-node loc))
                               (loc-rights loc))))
          (make-loc new-node
                   (loc-lefts parent)
                   (loc-rights parent)
                   (loc-parent parent)))
        #f)))

(define (zip-left loc)
  "Move to left sibling"
  (match (loc-lefts loc)
    ('() #f)
    ((l . ls)
     (make-loc l ls (cons (loc-node loc) (loc-rights loc)) (loc-parent loc)))))

(define (zip-right loc)
  "Move to right sibling"
  (match (loc-rights loc)
    ('() #f)
    ((r . rs)
     (make-loc r (cons (loc-node loc) (loc-lefts loc)) rs (loc-parent loc)))))

;;; Editing
(define (zip-replace loc new-node)
  "Replace current node"
  (make-loc new-node (loc-lefts loc) (loc-rights loc) (loc-parent loc)))

(define (zip-insert-left loc new-node)
  "Insert new node as left sibling"
  (make-loc (loc-node loc)
           (cons new-node (loc-lefts loc))
           (loc-rights loc)
           (loc-parent loc)))

(define (zip-insert-right loc new-node)
  "Insert new node as right sibling"
  (make-loc (loc-node loc)
           (loc-lefts loc)
           (cons new-node (loc-rights loc))
           (loc-parent loc)))

(define (zip-delete loc)
  "Delete current node, move to right sibling or left if no right"
  (match (loc-rights loc)
    ((r . rs)
     (make-loc r (loc-lefts loc) rs (loc-parent loc)))
    ('()
     (match (loc-lefts loc)
       ((l . ls)
        (make-loc l ls '() (loc-parent loc)))
       ('()
        ;; Only child - can't delete, return unchanged
        loc)))))

(define (zip-root loc)
  "Get root sexp from any position"
  (if (loc-parent loc)
      (zip-root (zip-up loc))
      (loc-node loc)))

;;; Paredit operations
(define (zip-slurp-right loc)
  "Pull next sibling from parent into this list (at end)"
  (and (pair? (loc-node loc))
       (loc-parent loc)
       (not (null? (loc-rights (loc-parent loc))))
       (let* ((parent (loc-parent loc))
              (sibling (car (loc-rights parent)))
              (new-node (append (loc-node loc) (list sibling)))
              (new-parent (make-loc (loc-node parent)
                                   (loc-lefts parent)
                                   (cdr (loc-rights parent))
                                   (loc-parent parent))))
         (make-loc new-node (loc-lefts loc) (loc-rights loc) new-parent))))

(define (zip-barf-right loc)
  "Push last child of this list out to parent (as right sibling)"
  (and (pair? (loc-node loc))
       (not (null? (loc-node loc)))
       (loc-parent loc)
       (let* ((node-list (loc-node loc))
              (last-child (last node-list))
              (new-node (drop-right node-list 1))
              (parent (loc-parent loc))
              (new-parent (make-loc (loc-node parent)
                                   (loc-lefts parent)
                                   (cons last-child (loc-rights parent))
                                   (loc-parent parent))))
         (if (null? new-node)
             #f  ; Can't barf only child
             (make-loc new-node (loc-lefts loc) (loc-rights loc) new-parent)))))

(define (zip-wrap loc wrapper-symbol)
  "Wrap current node in a list with wrapper-symbol as first element"
  (let ((new-node (list wrapper-symbol (loc-node loc))))
    (make-loc new-node (loc-lefts loc) (loc-rights loc) (loc-parent loc))))

(define (zip-splice loc)
  "Remove current list, promote children to siblings"
  (and (pair? (loc-node loc))
       (loc-parent loc)
       (let* ((children (loc-node loc))
              (parent (loc-parent loc))
              ;; Insert children as siblings
              (new-lefts (append (reverse children) (loc-lefts loc)))
              (new-parent (make-loc (loc-node parent)
                                   new-lefts
                                   (loc-rights loc)
                                   (loc-parent parent))))
         ;; Position on first child (now a sibling)
         (if (null? children)
             #f
             (make-loc (car (reverse children))
                      (cdr new-lefts)
                      (loc-rights loc)
                      new-parent)))))

(define (zip-raise loc)
  "Replace parent with current node"
  (and (loc-parent loc)
       (let* ((parent (loc-parent loc))
              (grandparent (loc-parent parent)))
         (make-loc (loc-node loc)
                  (loc-lefts parent)
                  (loc-rights parent)
                  grandparent))))
