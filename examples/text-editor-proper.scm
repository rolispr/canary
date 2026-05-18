#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary app)
             (canary protocol)
             (canary component)
             (canary components textarea)
             (canary style)
             (canary layout)
             (canary borders)
             (oop goops)
             (ice-9 format))

;;; Model
(define-class <model> ()
  (editor #:init-value #f #:accessor editor))

;;; Init
(define (init m)
  ;; Create textarea component that fills most of screen
  (set! (editor m) (make-textarea #:width 110 #:height 35 #:zone-id "editor"))
  ;; Focus it so it receives input
  (component-focus! (editor m))
  ;; Set initial content
  (textarea-set-value! (editor m)
                      "Welcome to the text editor!\nhjkl or arrows to move\nType to insert, backspace to delete\nEnter for new line\nq to quit\n\nStart typing...")
  #f)

;;; Update
(define (update m msg)
  (cond
   ;; Quit on q (only when editor not focused, or handle specially)
   ((and (is-a? msg <key-msg>)
         (char? (key msg))
         (or (char=? (key msg) #\Q)))
    (values m (quit-cmd)))

   ;; Everything else handled by component auto-delegation
   (else (values m #f))))

;;; View
(define (view m)
  (vbox
   (pad (align (txt "Text Editor - Arrow keys to move, type to insert, Q to quit" #:bold? #t #:fg "#ff6b9d") 'center) #:bottom 1)
   (boxed (textarea-view (editor m))
          #:border border-rounded
          #:fg "#666")
   (spacer 1)
   (txt "Full-featured multi-line editor with vi-style navigation" #:fg "#888")))

;;; Run
(define model (make <model>))
(define app (make-app model (current-module)))
(run-app app)
