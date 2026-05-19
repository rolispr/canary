(define-module (canary protocol)
  #:use-module (srfi srfi-9)
  #:export (<size> size size? size-width size-height

            <key> key key? key-char key-mods

            <mouse> mouse mouse?
            mouse-x mouse-y mouse-button mouse-action

            <tick> tick tick? tick-n

            <resize> resize resize? resize-width resize-height

            batch sequence batch? sequence?
            every every?
            after after?))

(define-record-type <size>
  (size width height) size?
  (width  size-width)
  (height size-height))

(define-record-type <key>
  (%key char mods) key?
  (char key-char)
  (mods key-mods))

(define* (key char #:optional (mods '()))
  (%key char mods))

(define-record-type <mouse>
  (mouse x y button action) mouse?
  (x      mouse-x)
  (y      mouse-y)
  (button mouse-button)
  (action mouse-action))

(define-record-type <tick>
  (%tick n) tick?
  (n tick-n))

(define* (tick #:optional (n 0)) (%tick n))

(define-record-type <resize>
  (resize width height) resize?
  (width  resize-width)
  (height resize-height))

(define (batch . cmds) (cons 'batch cmds))
(define (sequence . cmds) (cons 'sequence cmds))
(define (batch? c)    (and (pair? c) (eq? (car c) 'batch)))
(define (sequence? c) (and (pair? c) (eq? (car c) 'sequence)))

(define (every . args)
  ;; Usage: (every #:hz N producer) | (every #:seconds S producer) | (every #:ms MS producer)
  (let loop ((args args) (period #f))
    (cond
     ((null? args)       (error "every: pass producer thunk last"))
     ((null? (cdr args))
      (unless period    (error "every: pass #:hz, #:seconds, or #:ms"))
      (list 'every period (car args)))
     (else
      (let ((k (car args)) (v (cadr args)))
        (case k
          ((#:hz)      (loop (cddr args) (/ 1 v)))
          ((#:seconds) (loop (cddr args) v))
          ((#:ms)      (loop (cddr args) (/ v 1000)))
          (else        (error "every: unknown keyword" k))))))))
(define (every? c) (and (pair? c) (eq? (car c) 'every)))

(define (after . args)
  ;; Usage: (after #:ms N producer) | (after #:seconds S producer) | (after #:hz N producer)
  ;; One-shot: producer fires once after the delay; not rescheduled.
  (let loop ((args args) (delay #f))
    (cond
     ((null? args)      (error "after: pass producer thunk last"))
     ((null? (cdr args))
      (unless delay    (error "after: pass #:ms, #:seconds, or #:hz"))
      (list 'after delay (car args)))
     (else
      (let ((k (car args)) (v (cadr args)))
        (case k
          ((#:ms)      (loop (cddr args) (/ v 1000)))
          ((#:seconds) (loop (cddr args) v))
          ((#:hz)      (loop (cddr args) (/ 1 v)))
          (else        (error "after: unknown keyword" k))))))))
(define (after? c) (and (pair? c) (eq? (car c) 'after)))
