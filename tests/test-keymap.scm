(add-to-load-path (string-append (dirname (current-filename)) "/.."))

(use-modules (srfi srfi-64)
             (canary chord)
             (canary keymap))

(test-begin "keymap")

(define km
  (make-keymap
   (list (cons (list (chord #\q)) ':quit)
         (cons (list (chord #\x 'control)
                     (chord #\c 'control)) ':force-quit))))

(test-equal "single chord match"
            ':quit
            (call-with-values (lambda () (keymap-step km (chord #\q)))
                              (lambda (r _) r)))

(test-equal "non-match returns #f"
            #f
            (call-with-values (lambda () (keymap-step km (chord #\z)))
                              (lambda (r _) r)))

(test-equal "chord prefix returns pending"
            'pending
            (call-with-values (lambda () (keymap-step km (chord #\x 'control)))
                              (lambda (r _) r)))

(test-equal "second chord of sequence completes binding"
            ':force-quit
            (call-with-values
                (lambda ()
                  (call-with-values (lambda () (keymap-step km (chord #\x 'control)))
                                    (lambda (_ km2)
                                      (keymap-step km2 (chord #\c 'control)))))
              (lambda (r _) r)))

(test-end "keymap")
