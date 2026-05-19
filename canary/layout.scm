(define-module (canary layout)
  #:use-module (canary view)
  #:use-module (canary faces)
  #:use-module (srfi srfi-1)
  #:export (txt
            vbox
            hbox
            spacer
            join
            pad
            align
            width
            height
            fill
            place-cursor
            pin
            overlay
            static))

(define %empty-text (make-text-node "" 'default '()))

(define* (txt str #:key (face 'default) bold? italic? underline? strikethrough? reverse?)
  (let ((attrs '()))
    (when bold?         (set! attrs (cons 'bold attrs)))
    (when italic?       (set! attrs (cons 'italic attrs)))
    (when underline?    (set! attrs (cons 'underline attrs)))
    (when strikethrough? (set! attrs (cons 'strikethrough attrs)))
    (when reverse?      (set! attrs (cons 'reverse attrs)))
    (if (and (string? str) (string-null? str)
             (eq? face 'default) (null? attrs))
        %empty-text
        (make-text-node str face attrs))))

(define (split-face-arg args)
  (let lp ((args args) (children '()) (face #f))
    (cond
     ((null? args) (values (reverse children) face))
     ((eq? (car args) #:face) (lp (cddr args) children (cadr args)))
     (else (lp (cdr args) (cons (car args) children) face)))))

(define (vbox . args)
  (call-with-values (lambda () (split-face-arg args))
    (lambda (children face)
      (make-vbox-node (filter (lambda (x) x) children) face))))

(define (hbox . args)
  (call-with-values (lambda () (split-face-arg args))
    (lambda (children face)
      (make-hbox-node (filter (lambda (x) x) children) face))))

(define %zero-spacer (make-spacer-node 0 0))

(define* (spacer #:optional (n #f) #:key (w 0) (h 0))
  (cond
   ((and (not n) (zero? w) (zero? h)) %zero-spacer)
   ((not n) (make-spacer-node w h))
   ((eqv? n 0) %zero-spacer)
   (else (make-spacer-node w n))))

(define (static child) (make-static-node child))

(define (join . elements)
  (apply vbox elements))

(define* (pad child #:key (top 0) (right 0) (bottom 0) (left 0) (all 0) (face #f))
  (let ((t (if (positive? all) all top))
        (r (if (positive? all) all right))
        (b (if (positive? all) all bottom))
        (l (if (positive? all) all left)))
    (make-pad-node child t r b l face)))

(define* (align child mode #:key (width #f))
  (make-align-node child mode width))

(define* (width child w #:key (align 'left))
  (make-width-node child w align))

(define* (height child h #:key (valign 'top))
  (make-height-node child h valign))

(define* (fill w h #:key (face 'default))
  (make-fill-node w h face))

(define* (place-cursor col row #:key (style 'block))
  (make-cursor-node col row style))

(define (pin col row child)
  (make-placement col row child))

(define (overlay base . pins)
  (make-overlay-node base pins))
