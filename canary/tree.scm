(define-module (canary tree)
  #:use-module (canary view)
  #:use-module (canary layout)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:export (<tree>
            make-tree
            tree-root
            tree-child
            tree-view
            default-enumerator
            rounded-enumerator))

(define (default-enumerator depth last-child?)
  (if last-child?
      (values "└── " "    ")
      (values "├── " "│   ")))

(define (rounded-enumerator depth last-child?)
  (if last-child?
      (values "╰── " "    ")
      (values "├── " "│   ")))

(define-class <tree> ()
  (root-text #:init-value #f #:accessor tree-root-text)
  (children #:init-value '() #:accessor tree-children)
  (enumerator #:init-value default-enumerator #:accessor tree-enumerator)
  (root-face #:init-value 'default #:accessor tree-root-face)
  (item-face #:init-value 'default #:accessor tree-item-face)
  (branch-face #:init-value 'dim #:accessor tree-branch-face))

(define* (make-tree #:key root)
  (let ((t (make <tree>)))
    (when root (set! (tree-root-text t) root))
    t))

(define (tree-root tree root-text)
  (set! (tree-root-text tree) root-text)
  tree)

(define (tree-child tree . children)
  (set! (tree-children tree) (append (tree-children tree) children))
  tree)

(define (tree-lines node depth prefix branch-face item-face)
  (let* ((root-text (tree-root-text node))
         (children (tree-children node))
         (enum (tree-enumerator node))
         (lines (if root-text
                    (list (hbox (txt prefix #:face branch-face)
                                (txt root-text #:face item-face)))
                    '())))
    (let loop ((cs children) (idx 0) (acc lines))
      (cond
       ((null? cs) (reverse acc))
       (else
        (let* ((child (car cs))
               (last? (= idx (- (length children) 1))))
          (call-with-values (lambda () (enum depth last?))
            (lambda (branch cont)
              (cond
               ((is-a? child <tree>)
                (let* ((sub (tree-lines child (+ depth 1)
                                        (string-append prefix branch)
                                        branch-face item-face))
                       (cont-prefix (string-append prefix cont))
                       (rest (if (null? sub) '()
                                 (map (lambda (ln)
                                        (hbox (txt cont-prefix #:face branch-face) ln))
                                      (cdr sub)))))
                  (loop (cdr cs) (+ idx 1)
                        (append (reverse rest)
                                (if (null? sub) acc (cons (car sub) acc))))))
               (else
                (loop (cdr cs) (+ idx 1)
                      (cons (hbox (txt (string-append prefix branch) #:face branch-face)
                                  (txt (format #f "~a" child) #:face item-face))
                            acc))))))))))))

(define (tree-view tree)
  (apply vbox (tree-lines tree 0 ""
                          (tree-branch-face tree)
                          (tree-item-face tree))))
