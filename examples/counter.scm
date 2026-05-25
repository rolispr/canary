;;; counter.scm — the canonical hello-world for canary.
;;;
;;; Run: guile -L /path/to/guile-canary examples/counter.scm
;;;
;;; Keys: + or k → increment; - or j → decrement; r → reset; q → quit.
;;;
;;; What this shows:
;;;   - define-node generates state record + accessors + constructor.
;;;   - react returns either #f or a cmd. Here, only 'quit is a cmd.
;;;   - subscribes filters: counter only sees keys.
;;;   - run-app takes any node and a keymap.

(use-modules (canary))

(define-node counter
  #:state ((n 0))
  #:subscribes (key?)
  #:view (lambda (c)
           (vbox (txt "  press + or - (q to quit)" #:fg 'muted)
                 (spacer 1)
                 (align (txt (number->string (counter-n c))
                             #:fg 'accent #:bold)
                        'center #:width 40)))
  #:react (lambda (c msg)
            (let ((k (key-sym msg)))
              (cond
               ((or (eqv? k #\+) (eqv? k #\k))
                (set! (counter-n c) (+ 1 (counter-n c))) #f)
               ((or (eqv? k #\-) (eqv? k #\j))
                (set! (counter-n c) (- (counter-n c) 1)) #f)
               ((eqv? k #\r)
                (set! (counter-n c) 0) #f)
               (else #f)))))

(run-app (make-counter)
         #:title  "counter"
         #:keymap (keymap (bind #\q 'quit) (bind 'escape 'quit))
         #:mouse  'off)
