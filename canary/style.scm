(define-module (canary style)
  #:use-module (canary faces)
  #:use-module (canary view)
  #:export (with-face
            with-attrs
            bold
            italic
            underline
            strikethrough
            reverse-video))

(define (as-text-node node face attrs)
  (cond
   ((text-node? node)
    (make-text-node (text-node-str node)
                    (or face (text-node-face node))
                    (append (text-node-attrs node) attrs)))
   ((string? node)
    (make-text-node node (or face 'default) attrs))
   (else node)))

(define (with-face face node)
  (as-text-node node face '()))

(define (with-attrs node . attrs)
  (as-text-node node #f attrs))

(define (bold node)        (with-attrs node 'bold))
(define (italic node)      (with-attrs node 'italic))
(define (underline node)   (with-attrs node 'underline))
(define (strikethrough node) (with-attrs node 'strikethrough))
(define (reverse-video node) (with-attrs node 'reverse))
