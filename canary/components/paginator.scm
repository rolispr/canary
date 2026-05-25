(define-module (canary components paginator)
  #:use-module (canary node)
  #:use-module (canary layout)
  #:use-module (canary protocol)
  #:use-module (canary key)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (<paginator-state>
            paginator?
            make-paginator
            paginator-type
            paginator-page
            paginator-per-page
            paginator-total-pages
            paginator-prev-page!
            paginator-next-page!
            paginator-on-first-page?
            paginator-on-last-page?
            paginator-get-slice-bounds))

(define-node paginator
  #:state ((type 'arabic)
           (page 0)
           (per-page 10)
           (total-pages 1)
           (active-dot "•")
           (inactive-dot "○")
           (arabic-format "~d/~d"))
  #:subscribes (key?)
  #:view
  (lambda (p)
    (case (paginator-type p)
      ((dots) (paginator-dots-view p))
      (else   (paginator-arabic-view p))))
  #:react
  (lambda (p msg)
    (let ((k (key-sym msg)))
      (match k
        ((or 'right 'page-down)         (paginator-next-page! p))
        ((or 'left  'page-up)           (paginator-prev-page! p))
        ((? (lambda (c) (and (char? c) (char=? c #\l)))) (paginator-next-page! p))
        ((? (lambda (c) (and (char? c) (char=? c #\h)))) (paginator-prev-page! p))
        (_ #f))
      #f)))

(define (paginator-prev-page! p)
  (when (> (paginator-page p) 0)
    (set! (paginator-page p) (- (paginator-page p) 1)))
  p)

(define (paginator-next-page! p)
  (when (< (paginator-page p) (- (paginator-total-pages p) 1))
    (set! (paginator-page p) (+ (paginator-page p) 1)))
  p)

(define (paginator-on-first-page? p) (= (paginator-page p) 0))
(define (paginator-on-last-page? p)
  (= (paginator-page p) (- (paginator-total-pages p) 1)))

(define (paginator-get-slice-bounds p length)
  (if (zero? length)
      (values 0 0)
      (let* ((page     (paginator-page p))
             (per-page (paginator-per-page p))
             (start    (min (* page per-page) length))
             (end      (min (+ start per-page) length)))
        (values start end))))

(define (paginator-dots-view p)
  (let ((total   (paginator-total-pages p))
        (current (paginator-page p)))
    (apply hbox
           (map (lambda (i)
                  (if (= i current)
                      (txt "•" #:fg 'accent)
                      (txt "○" #:fg 'muted)))
                (iota total)))))

(define (paginator-arabic-view p)
  (let ((current (+ 1 (paginator-page p)))
        (total   (paginator-total-pages p)))
    (txt (format #f "~d/~d" current total) #:fg 'muted)))
