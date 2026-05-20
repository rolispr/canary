(define-module (canary keymap-input)
  #:use-module (canary key)
  #:use-module (canary keymap)
  #:use-module (canary protocol)
  #:export (feed-key
            mouse->key))

(define (mouse->key msg)
  (let ((a (mouse-action msg))
        (b (mouse-button msg)))
    (case a
      ((press click)
       (case b
         ((0) (key (cons 'mouse 'left)))
         ((1) (key (cons 'mouse 'middle)))
         ((2) (key (cons 'mouse 'right)))
         (else #f)))
      ((scroll-up)   (key (cons 'mouse-scroll 'up)))
      ((scroll-down) (key (cons 'mouse-scroll 'down)))
      (else #f))))

(define (feed-key km msg)
  (cond
   ((key? msg)   (keymap-step km msg))
   ((mouse? msg) (let ((k (mouse->key msg)))
                   (if k (keymap-step km k) (values #f km))))
   (else (values #f km))))
