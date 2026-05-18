(define-module (canary keymap-input)
  #:use-module (canary chord)
  #:use-module (canary keymap)
  #:use-module (canary protocol)
  #:use-module (oop goops)
  #:export (key-msg->chord
            feed-key-msg))

(define (key-msg->chord km)
  (let ((mods '()))
    (when (alt km)  (set! mods (cons 'meta mods)))
    (when (ctrl km) (set! mods (cons 'control mods)))
    (make-chord (key km) mods)))

(define (feed-key-msg keymap msg)
  (cond
   ((not (is-a? msg <key-msg>)) (values #f keymap))
   (else
    (let ((c (key-msg->chord msg)))
      (keymap-step keymap c)))))
