(define-module (canary backend)
  #:use-module (oop goops)
  #:export (<backend>
            backend-init
            backend-shutdown
            backend-draw
            backend-size))

(define-class <backend> ())

(define-generic backend-init)
(define-generic backend-shutdown)
(define-generic backend-draw)
(define-generic backend-size)
