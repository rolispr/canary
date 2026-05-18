(define-module (canary table)
  #:use-module (canary view)
  #:use-module (canary layout)
  #:use-module (canary borders)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (<table>
            table?
            make-table
            table-add-row
            table-view))

(define-record-type <table>
  (%make-table headers rows border header-face)
  table?
  (headers table-headers set-table-headers!)
  (rows table-rows set-table-rows!)
  (border table-border)
  (header-face table-header-face))

(define* (make-table #:key (headers '()) (rows '())
                     (border border-normal)
                     (header-face 'heading))
  (%make-table headers rows border header-face))

(define (table-add-row tbl row)
  (set-table-rows! tbl (append (table-rows tbl) (list row)))
  tbl)

(define (col-widths headers rows)
  (let ((all (cons headers rows)))
    (cond
     ((null? headers) '())
     (else
      (map (lambda (i)
             (apply max (map (lambda (r) (string-length (list-ref r i))) all)))
           (iota (length headers)))))))

(define (cell-row cells widths face)
  (apply hbox
         (apply append
                (map (lambda (text w)
                       (list (txt " ")
                             (txt (string-pad-right text w) #:face face)
                             (txt " │")))
                     cells widths))))

(define (string-pad-right s w)
  (let ((n (string-length s)))
    (cond
     ((>= n w) s)
     (else (string-append s (make-string (- w n) #\space))))))

(define (table-view tbl)
  (let* ((headers (table-headers tbl))
         (rows (table-rows tbl))
         (widths (col-widths headers rows))
         (face (table-header-face tbl)))
    (boxed
     (apply vbox
            (cons (cell-row headers widths face)
                  (map (lambda (r) (cell-row r widths 'default)) rows)))
     #:border (table-border tbl))))
