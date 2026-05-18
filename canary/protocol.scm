(define-module (canary protocol)
  #:use-module (oop goops)
  #:export (<key-msg>
            <quit-msg>
            <window-size-msg>
            <mouse-msg>
            <command-msg>
            <tick-msg>
            key
            alt
            ctrl
            width
            height
            x
            y
            button
            action
            command
            command-args
            tick
            quit-cmd
            batch-cmd
            sequence-cmd))

(define-class <key-msg> ()
  (key #:init-keyword #:key #:accessor key)
  (alt #:init-keyword #:alt #:init-value #f #:accessor alt)
  (ctrl #:init-keyword #:ctrl #:init-value #f #:accessor ctrl))

(define-class <quit-msg> ())

(define-class <window-size-msg> ()
  (width #:init-keyword #:width #:accessor width)
  (height #:init-keyword #:height #:accessor height))

(define-class <mouse-msg> ()
  (x #:init-keyword #:x #:accessor x)
  (y #:init-keyword #:y #:accessor y)
  (button #:init-keyword #:button #:accessor button)
  (action #:init-keyword #:action #:accessor action))

(define-class <command-msg> ()
  (command #:init-keyword #:command #:accessor command)
  (command-args #:init-keyword #:args #:init-value '() #:accessor command-args))

(define-class <tick-msg> ()
  (tick #:init-keyword #:tick #:init-value 0 #:accessor tick))

(define (quit-cmd)
  (lambda () (make <quit-msg>)))

(define (batch-cmd . cmds)
  (cons 'batch cmds))

(define (sequence-cmd . cmds)
  (cons 'sequence cmds))
