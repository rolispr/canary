(define-module (canary chord)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (<chord>
            chord?
            make-chord
            chord
            chord-keysym
            chord-mods
            chord=?
            chord->string))

(define-record-type <chord>
  (%make-chord keysym mods)
  chord?
  (keysym chord-keysym)
  (mods chord-mods))

(define (sort-mods mods)
  (sort (delete-duplicates mods)
        (lambda (a b)
          (string<? (symbol->string a) (symbol->string b)))))

(define (make-chord keysym mods)
  (%make-chord keysym (sort-mods mods)))

(define (chord k . mods)
  (make-chord k mods))

(define (chord=? a b)
  (and (chord? a) (chord? b)
       (equal? (chord-keysym a) (chord-keysym b))
       (equal? (chord-mods a) (chord-mods b))))

(define (chord->string c)
  (let ((mods (chord-mods c))
        (k (chord-keysym c)))
    (string-append
     (apply string-append
            (map (lambda (m)
                   (case m
                     ((control) "C-")
                     ((meta) "M-")
                     ((shift) "S-")
                     (else (string-append (symbol->string m) "-"))))
                 mods))
     (cond
      ((char? k) (string k))
      ((symbol? k) (symbol->string k))
      (else (format #f "~a" k))))))
