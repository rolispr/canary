#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))

(use-modules (canary app)
             (canary protocol)
             (canary layout)
             (canary borders)
             (canary chord)
             (canary keymap)
             (oop goops))

(define-class <model> ()
  (counter #:init-value 0 #:accessor counter))

(define (init m) #f)

(define app-keymap
  (make-keymap
   (list (cons (list (chord #\q)) ':quit)
         (cons (list (chord #\Q)) ':quit)
         (cons (list (chord #\j)) ':inc)
         (cons (list (chord #\k)) ':dec))))

(define (update m msg)
  (cond
   ((is-a? msg <command-msg>)
    (case (command msg)
      ((:quit) (values m (quit-cmd)))
      ((:inc) (set! (counter m) (+ (counter m) 1)) (values m #f))
      ((:dec) (set! (counter m) (- (counter m) 1)) (values m #f))
      (else (values m #f))))
   (else (values m #f))))

(define (view m)
  (vbox
   (txt "Minimal Counter" #:face 'accent #:bold? #t)
   (spacer 1)
   (boxed (txt (string-append "Counter: " (number->string (counter m))))
          #:border border-double
          #:face 'success)
   (spacer 1)
   (txt "j increment · k decrement · q quit" #:face 'dim)))

(define model (make <model>))
(define app (make-app model (current-module) #:keymap app-keymap))
(run-app app)
