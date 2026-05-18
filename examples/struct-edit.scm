#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary terminal)
             (canary style)
             (canary protocol)
             (canary app)
             (canary layout)
             (canary borders)
             (canary zipper)
             (ice-9 match)
             (ice-9 format)
             (ice-9 pretty-print)
             (oop goops)
             (srfi srfi-1))

(define-class <model> ()
  (root #:init-keyword #:root #:accessor root)     ; root sexp (list of top-level forms)
  (loc #:init-keyword #:loc #:accessor loc))       ; zipper location

(define (init m) #f)

(define (update m msg)
  (catch #t
    (lambda ()
      (cond
       ((and (is-a? msg <key-msg>) (char? (key msg)) (char=? (key msg) #\q))
        (values m (quit-cmd)))
       ((is-a? msg <key-msg>)
        (let ((k (key msg))
              (l (loc m)))
          (match k
            ;; Navigation
            (#\j  ; down to next sibling
             (let ((new-loc (zip-right l)))
               (when new-loc (set! (loc m) new-loc)))
             (values m #f))
            (#\k  ; up to previous sibling
             (let ((new-loc (zip-left l)))
               (when new-loc (set! (loc m) new-loc)))
             (values m #f))
            (#\l  ; right - into first child
             (let ((new-loc (zip-down l)))
               (when new-loc (set! (loc m) new-loc)))
             (values m #f))
            (#\h  ; left - out to parent
             (let ((new-loc (zip-up l)))
               (when new-loc (set! (loc m) new-loc)))
             (values m #f))

            ;; Editing - paredit operations
            (#\s  ; slurp right
             (let ((new-loc (zip-slurp-right l)))
               (when new-loc
                 (set! (loc m) new-loc)
                 (set! (root m) (zip-root new-loc))))
             (values m #f))
            (#\b  ; barf right
             (let ((new-loc (zip-barf-right l)))
               (when new-loc
                 (set! (loc m) new-loc)
                 (set! (root m) (zip-root new-loc))))
             (values m #f))
            (#\w  ; wrap in list
             (let ((new-loc (zip-wrap l 'list)))
               (set! (loc m) new-loc)
               (set! (root m) (zip-root new-loc)))
             (values m #f))
            (#\r  ; raise - replace parent with current node
             (let ((new-loc (zip-raise l)))
               (when new-loc
                 (set! (loc m) new-loc)
                 (set! (root m) (zip-root new-loc))))
             (values m #f))

            (_ (values m #f)))))
       (else (values m #f))))
    (lambda (key . args)
      (log-error app (format #f "~a" args))
      (values m #f))))

;; Just pretty-print the code as text
(define (render-as-text root loc)
  (let* ((current (zip-node loc))
         ;; Pretty print entire file
         (text (call-with-output-string
                (lambda (port)
                  (for-each (lambda (sexp)
                              (pretty-print sexp port)
                              (newline port))
                            root))))
         ;; Split into lines
         (lines (string-split text #\newline))
         ;; Filter empty lines
         (non-empty (filter (lambda (s) (not (string-null? s))) lines)))

    (apply vbox
           (append
            ;; Show all lines as text
            (map (lambda (line) (txt line #:fg "#8ac")) non-empty)
            ;; Show current node at bottom
            (list (spacer 1)
                  (hbox (txt "► " #:fg "#0ff")
                        (txt (format #f "~s" current) #:fg "#0f0")))))))

(define (view m)
  (catch #t
    (lambda ()
      (let* ((r (root m))
             (l (loc m)))
        (vbox
         (txt "Structural Editor" #:bold? #t #:fg "#f6d")
         (spacer 1)
         (boxed
          (render-as-text r l)
          #:border border-rounded
          #:fg "#888")
         (spacer 1)
         (txt "hjkl=nav  s=slurp  b=barf  w=wrap  r=raise  q=quit" #:fg "#666")
         (error-console app))))
    (lambda (key . args)
      (log-error app (format #f "~a" args))
      (vbox (txt "ERROR" #:fg "#f00") (error-console app)))))

(define (load-file-as-sexps filename)
  "Read all s-expressions from a file"
  (call-with-input-file filename
    (lambda (port)
      (let loop ((sexps '()))
        (let ((sexp (read port)))
          (if (eof-object? sexp)
              (reverse sexps)
              (loop (cons sexp sexps))))))))

(define initial-code
  (load-file-as-sexps (current-filename)))

(define model (make <model>
                #:root initial-code
                #:loc (make-zipper initial-code)))
(define app (make-app model (current-module)))
(run-app app)
