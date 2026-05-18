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
             (canary zones)
             (oop goops)
             (ice-9 format))

;;; Model
(define-class <model> ()
  (editor #:init-value #f #:accessor editor))

;;; Init
(define (init m)
  ;; Create focused textarea component
  (set! (editor m) (make-textarea
                    #:width 76
                    #:height 18
                    #:zone-id "editor"))
  (component-focus! (editor m))
  (textarea-set-value! (editor m)
                      "Welcome to the Text Editor!\n\nArrow keys, Home/End to navigate\nType to insert text\nBackspace/Delete to remove\nEnter for new line\nEsc to unfocus, Q to quit\n\nStart typing to edit this text...")
  #f)

;;; Update
(define (update m msg)
  (cond
   ;; Quit on Q (capital Q only, when editor not focused)
   ((and (is-a? msg <key-msg>)
         (char? (key msg))
         (char=? (key msg) #\Q)
         (not (component-focused? (editor m))))
    (values m (quit-cmd)))

   ;; All other keys handled by component auto-delegation
   (else (values m #f))))

;;; View
(define (view m)
  (let* ((title "Text Editor")
         (status (if (component-focused? (editor m))
                    "Focused - Type to edit | Esc=unfocus"
                    "Unfocused - Q=quit"))
         (content (vbox
                   (pad (align (txt title #:bold? #t #:fg "#ff6b9d") 'center) #:bottom 1)
                   (boxed (textarea-view (editor m))
                          #:border border-rounded
                          #:fg "#666")
                   (spacer 1)
                   (txt status #:fg "#888"))))
    ;; Wrap in zone-scan for mouse support
    (zone-scan content)))

;;; Run
(define model (make <model>))
(define app (make-app model (current-module)))
(run-app app)
