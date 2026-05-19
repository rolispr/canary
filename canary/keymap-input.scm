(define-module (canary keymap-input)
  #:use-module (canary chord)
  #:use-module (canary keymap)
  #:use-module (canary protocol)
  #:export (key->chord
            feed-key))

(define (key->chord k)
  (make-chord (key-char k) (key-mods k)))

(define (feed-key keymap msg)
  (if (key? msg)
      (keymap-step keymap (key->chord msg))
      (values #f keymap)))
