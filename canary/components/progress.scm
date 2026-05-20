(define-module (canary components progress)
  #:use-module (canary view)
  #:use-module (canary layout)
  #:use-module (srfi srfi-9)
  #:export (<progress>
            progress?
            make-progress
            progress-set!
            progress-view
            progress-percent))

(define-record-type <progress>
  (%make-progress current total width show-percent? filled-face empty-face)
  progress?
  (current progress-current set-progress-current!)
  (total progress-total)
  (width progress-width)
  (show-percent? progress-show-percent?)
  (filled-face progress-filled-face)
  (empty-face progress-empty-face))

(define* (make-progress #:key (current 0) (total 100) (width 40)
                        (show-percent? #t)
                        (filled-face 'success)
                        (empty-face 'dim))
  (%make-progress current total width show-percent? filled-face empty-face))

(define (progress-set! p v)
  (set-progress-current! p v)
  p)

(define (progress-percent p)
  (let ((c (progress-current p))
        (t (progress-total p)))
    (if (zero? t) 0
        (inexact->exact (floor (* 100 (/ c t)))))))

(define (progress-view p)
  (let* ((pct (progress-percent p))
         (w (progress-width p))
         (filled (inexact->exact (floor (* w (/ pct 100)))))
         (empty (- w filled)))
    (apply hbox
           (txt "[")
           (txt (make-string filled #\█) #:fg (progress-filled-face p))
           (txt (make-string empty #\░) #:fg (progress-empty-face p))
           (txt "]")
           (if (progress-show-percent? p)
               (list (txt (string-append " " (number->string pct) "%")))
               '()))))
