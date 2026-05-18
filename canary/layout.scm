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
            place-cursor))

(define* (txt str #:key (face 'default) bold? italic? underline? strikethrough? reverse?)
  (let ((attrs '()))
    (when bold?         (set! attrs (cons 'bold attrs)))
    (when italic?       (set! attrs (cons 'italic attrs)))
    (when underline?    (set! attrs (cons 'underline attrs)))
    (when strikethrough? (set! attrs (cons 'strikethrough attrs)))
    (when reverse?      (set! attrs (cons 'reverse attrs)))
    (make-text-node str face attrs)))

(define (vbox . elements)
  (make-vbox-node (filter (lambda (x) x) elements)))

(define (hbox . elements)
  (make-hbox-node (filter (lambda (x) x) elements)))

(define (spacer n)
  (make-spacer-node 0 n))

(define (join . elements)
  (apply vbox elements))

(define* (pad child #:key (top 0) (right 0) (bottom 0) (left 0) (all 0))
  (let ((t (if (positive? all) all top))
        (r (if (positive? all) all right))
        (b (if (positive? all) all bottom))
        (l (if (positive? all) all left)))
    (make-pad-node child t r b l)))

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
