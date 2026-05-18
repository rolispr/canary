(define-module (canary keymap)
  #:use-module (canary chord)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (<keymap>
            keymap?
            make-keymap
            keymap-bindings
            keymap-pending
            keymap-step
            keymap-reset))

(define-record-type <keymap>
  (%make-keymap bindings pending)
  keymap?
  (bindings keymap-bindings)
  (pending keymap-pending))

(define* (make-keymap #:optional (bindings '()))
  (%make-keymap bindings '()))

(define (keymap-reset km)
  (%make-keymap (keymap-bindings km) '()))

(define (chord-list=? a b)
  (and (= (length a) (length b))
       (every chord=? a b)))

(define (chord-prefix? prefix candidate)
  (and (<= (length prefix) (length candidate))
       (chord-list=? prefix (take candidate (length prefix)))))

(define (keymap-step km c)
  (let* ((pending (append (keymap-pending km) (list c)))
         (bindings (keymap-bindings km))
         (exact (find (lambda (entry) (chord-list=? pending (car entry)))
                      bindings))
         (any-prefix?
          (any (lambda (entry) (chord-prefix? pending (car entry)))
               bindings)))
    (cond
     (exact
      (values (cdr exact) (%make-keymap bindings '())))
     (any-prefix?
      (values 'pending (%make-keymap bindings pending)))
     (else
      (values #f (%make-keymap bindings '()))))))
