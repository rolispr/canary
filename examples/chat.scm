;;; chat.scm — two stateful nodes composed: a message list + an input.
;;;
;;; Run: guile -L /path/to/guile-canary examples/chat.scm
;;;
;;; Type a line and press enter to add it to the log. ctrl-c to quit.
;;;
;;; What this shows:
;;;   - composition of two independent stateful nodes (chatlog + input)
;;;     inside a layout — no msg forwarding by the parent. The cascade
;;;     hits each one with each msg; each filters via subscribes.
;;;   - a user-defined msg ('chat-submit) sent from one node's react,
;;;     dispatched into the cascade, picked up by the other node.
;;;   - the bundled textinput component as a drop-in node.

(use-modules (canary)
             (canary components panel)
             (canary components textinput))

;; ── chatlog: appends a line whenever it sees a 'chat-submit msg. ────

(define-node chatlog
  #:state ((lines '()))
  #:subscribes ((lambda (m)
                  (and (pair? m) (eq? (car m) 'chat-submit))))
  #:view (lambda (cl)
           (let ((ls (chatlog-lines cl)))
             (cond
              ((null? ls)
               (txt "(no messages yet — type below)" #:fg 'muted #:italic))
              (else
               (apply vbox
                      (map (lambda (line)
                             (hbox (txt "▸ " #:fg 'accent)
                                   (txt line)))
                           (reverse ls)))))))
  #:react (lambda (cl msg)
            (set! (chatlog-lines cl) (cons (cadr msg) (chatlog-lines cl)))
            #f))

;; ── input row: textinput + a node that watches for the return key,
;; sends 'chat-submit with the input's contents, and clears it. ──────

(define ti (make-textinput #:prompt "> " #:placeholder "say something" #:width 40))

(set! (textinput-focused? ti) #t)

(define-node submitter
  #:state ((input ti))
  #:subscribes (key?)
  #:view (lambda (_) (spacer 0))   ; no visible UI
  #:react (lambda (s msg)
            (let ((k (key-sym msg)))
              (cond
               ((or (eq? k 'return) (eqv? k #\newline) (eqv? k #\return))
                (let ((val (textinput-value (submitter-input s))))
                  (cond
                   ((zero? (string-length val)) #f)
                   (else
                    (set! (textinput-value (submitter-input s)) "")
                    (set! (textinput-cursor (submitter-input s)) 0)
                    ;; user thunk → engine spawns fiber → returns msg
                    ;; that re-enters the cascade. chatlog picks it up.
                    (lambda () `(chat-submit ,val))))))
               (else #f)))))

(define cl (make-chatlog))

(define app
  (vbox
   (make-panel #:title "chat" #:face 'muted #:content cl)
   (spacer 1)
   ti
   ;; submitter is invisible but lives in the tree so the cascade
   ;; reaches it. Same trick works for any "controller" node.
   (make-submitter)))

(run-app app
         #:title  "chat"
         #:keymap (keymap (bind '(#\c ctrl) 'quit))
         #:mouse  'off)
