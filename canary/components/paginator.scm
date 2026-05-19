;;; components/paginator.scm --- Pagination component

(define-module (canary components paginator)
  #:use-module (canary protocol)
  #:use-module (canary component)
  #:use-module (ice-9 match)
  #:use-module (oop goops)
  #:export (make-paginator
            paginator-page
            paginator-per-page
            paginator-total-pages
            paginator-set-total-pages!
            paginator-get-slice-bounds
            paginator-prev-page!
            paginator-next-page!
            paginator-on-first-page?
            paginator-on-last-page?
            paginator-update
            paginator-view
            <paginator>))

;;; Display types
(define paginator-arabic 'arabic)
(define paginator-dots 'dots)

;;; Paginator class
(define-class <paginator> (<component>)
  (type #:init-keyword #:type #:init-value 'arabic #:accessor paginator-type)
  (page #:init-keyword #:page #:init-value 0 #:accessor paginator-page)
  (per-page #:init-keyword #:per-page #:init-value 10 #:accessor paginator-per-page)
  (total-pages #:init-keyword #:total-pages #:init-value 1 #:accessor paginator-total-pages)
  (active-dot #:init-keyword #:active-dot #:init-value "•" #:accessor paginator-active-dot)
  (inactive-dot #:init-keyword #:inactive-dot #:init-value "○" #:accessor paginator-inactive-dot)
  (arabic-format #:init-keyword #:arabic-format #:init-value "~d/~d" #:accessor paginator-arabic-format))

(define* (make-paginator #:key (type 'arabic) (per-page 10) (total-pages 1))
  "Create a new paginator"
  (make <paginator> #:type type #:per-page per-page #:total-pages total-pages))

;;; Helper functions
(define (paginator-set-total-pages! paginator items)
  "Calculate and set total pages from number of items"
  (when (< items 1)
    (paginator-total-pages paginator))
  (let* ((per-page (paginator-per-page paginator))
         (n (ceiling (/ items per-page))))
    (set! (paginator-total-pages paginator) n)
    n))

(define (paginator-get-slice-bounds paginator length)
  "Get start and end indices for current page"
  (if (zero? length)
      (values 0 0)
      (let* ((page (paginator-page paginator))
             (per-page (paginator-per-page paginator))
             (start (min (* page per-page) length))
             (end (min (+ start per-page) length)))
        (values start end))))

(define (paginator-prev-page! paginator)
  "Navigate to previous page"
  (when (> (paginator-page paginator) 0)
    (set! (paginator-page paginator) (1- (paginator-page paginator))))
  paginator)

(define (paginator-next-page! paginator)
  "Navigate to next page"
  (when (< (paginator-page paginator) (1- (paginator-total-pages paginator)))
    (set! (paginator-page paginator) (1+ (paginator-page paginator))))
  paginator)

(define (paginator-on-first-page? paginator)
  "Check if on first page"
  (= (paginator-page paginator) 0))

(define (paginator-on-last-page? paginator)
  "Check if on last page"
  (= (paginator-page paginator)
     (1- (paginator-total-pages paginator))))

;;; Rendering
(define (paginator-dots-view paginator)
  "Render pagination as dots"
  (let ((total (paginator-total-pages paginator))
        (current (paginator-page paginator))
        (active (paginator-active-dot paginator))
        (inactive (paginator-inactive-dot paginator)))
    (string-join
     (map (lambda (i)
            (if (= i current) active inactive))
          (iota total))
     "")))

(define (paginator-arabic-view paginator)
  "Render pagination as arabic numbers"
  (let ((fmt (paginator-arabic-format paginator))
        (current (1+ (paginator-page paginator)))
        (total (paginator-total-pages paginator)))
    (format #f fmt current total)))

;;; Update
(define (paginator-update paginator msg)
  "Update paginator with message"
  (cond
   ((key? msg)
    (let ((k (key-char msg)))
      (match k
        ((or 'right 'page-down)
         (paginator-next-page! paginator)
         (values paginator #t))

        ((or 'left 'page-up)
         (paginator-prev-page! paginator)
         (values paginator #t))

        (_
         (if (and (char? k)
                  (or (char=? k #\l) (char=? k #\h)))
             (begin
               (if (char=? k #\l)
                   (paginator-next-page! paginator)
                   (paginator-prev-page! paginator))
               (values paginator #t))
             (values paginator #f))))))

   (else (values paginator #f))))

;;; Component protocol
(define-method (react (paginator <paginator>) msg)
  "Handle messages via component protocol"
  (paginator-update paginator msg))

;;; View
(define (paginator-view paginator)
  "Render paginator"
  (case (paginator-type paginator)
    ((dots) (paginator-dots-view paginator))
    (else (paginator-arabic-view paginator))))
