#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary app)
             (canary protocol)
             (canary components grid)
             (canary style)
             (canary layout)
             (canary borders)
             (oop goops)
             (ice-9 format)
             (srfi srfi-1))

;;; Model
(define-class <model> ()
  (grid #:init-value #f #:accessor grid-obj)
  (lines #:init-keyword #:lines #:init-value '("") #:accessor lines)
  (cursor-row #:init-value 0 #:accessor cursor-row)
  (cursor-col #:init-value 0 #:accessor cursor-col))

;;; Init
(define (init m)
  (set! (grid-obj m) (make-grid #:width 76 #:height 20))
  ;; Populate grid with initial lines
  (let ((lns (lines m)))
    (do ((i 0 (1+ i)))
        ((>= i (min (length lns) 20)))
      (grid-set-line! (grid-obj m) i (list-ref lns i) "#aaa")))
  ;; Set cursor
  (grid-set-cursor! (grid-obj m) 0 0)
  #f)

;;; Update
(define (update m msg)
  (cond
   ;; Quit
   ((and (is-a? msg <key-msg>)
         (char? (key msg))
         (member (key msg) '(#\q #\Q)))
    (values m (quit-cmd)))

   ;; Navigation
   ((is-a? msg <key-msg>)
    (let ((k (key msg))
          (row (cursor-row m))
          (col (cursor-col m))
          (line-count (length (lines m))))
      (cond
       ;; Left / h
       ((or (eq? k 'left) (and (char? k) (char=? k #\h)))
        (when (> col 0)
          (set! (cursor-col m) (1- col))
          (grid-set-cursor! (grid-obj m) (1- col) row))
        (values m #f))

       ;; Down / j
       ((or (eq? k 'down) (and (char? k) (char=? k #\j)))
        (when (< row (1- line-count))
          (set! (cursor-row m) (1+ row))
          (let ((len (string-length (list-ref (lines m) (1+ row)))))
            (when (> col len)
              (set! (cursor-col m) len)
              (grid-set-cursor! (grid-obj m) len (1+ row))))
          (grid-set-cursor! (grid-obj m) (cursor-col m) (1+ row)))
        (values m #f))

       ;; Up / k
       ((or (eq? k 'up) (and (char? k) (char=? k #\k)))
        (when (> row 0)
          (set! (cursor-row m) (1- row))
          (let ((len (string-length (list-ref (lines m) (1- row)))))
            (when (> col len)
              (set! (cursor-col m) len)
              (grid-set-cursor! (grid-obj m) len (1- row))))
          (grid-set-cursor! (grid-obj m) (cursor-col m) (1- row)))
        (values m #f))

       ;; Right / l
       ((or (eq? k 'right) (and (char? k) (char=? k #\l)))
        (let ((len (string-length (list-ref (lines m) row))))
          (when (< col len)
            (set! (cursor-col m) (1+ col))
            (grid-set-cursor! (grid-obj m) (1+ col) row)))
        (values m #f))

       ;; Home / 0
       ((or (eq? k 'home) (and (char? k) (char=? k #\0)))
        (set! (cursor-col m) 0)
        (grid-set-cursor! (grid-obj m) 0 row)
        (values m #f))

       ;; End / $
       ((or (eq? k 'end) (and (char? k) (char=? k #\$)))
        (let ((len (string-length (list-ref (lines m) row))))
          (set! (cursor-col m) len)
          (grid-set-cursor! (grid-obj m) len row))
        (values m #f))

       ;; First line / g
       ((and (char? k) (char=? k #\g))
        (set! (cursor-row m) 0)
        (grid-set-cursor! (grid-obj m) (cursor-col m) 0)
        (values m #f))

       ;; Last line / G
       ((and (char? k) (char=? k #\G))
        (set! (cursor-row m) (1- line-count))
        (grid-set-cursor! (grid-obj m) (cursor-col m) (1- line-count))
        (values m #f))

       ;; Insert character
       ((and (char? k) (char-graphic? k))
        (let* ((line (list-ref (lines m) row))
               (new-line (string-append (substring line 0 col)
                                        (string k)
                                        (substring line col)))
               (new-lines (append (take (lines m) row)
                                  (list new-line)
                                  (drop (lines m) (1+ row)))))
          (set! (lines m) new-lines)
          (set! (cursor-col m) (1+ col))
          ;; Update grid line
          (grid-set-line! (grid-obj m) row new-line "#aaa")
          (grid-set-cursor! (grid-obj m) (1+ col) row)
          (values m #f)))

       ;; Backspace
       ((eq? k 'backspace)
        (cond
         ((> col 0)
          (let* ((line (list-ref (lines m) row))
                 (new-line (string-append (substring line 0 (1- col))
                                          (substring line col)))
                 (new-lines (append (take (lines m) row)
                                    (list new-line)
                                    (drop (lines m) (1+ row)))))
            (set! (lines m) new-lines)
            (set! (cursor-col m) (1- col))
            (grid-set-line! (grid-obj m) row new-line "#aaa")
            (grid-set-cursor! (grid-obj m) (1- col) row)
            (values m #f)))
         ((> row 0)
          (let* ((prev (list-ref (lines m) (1- row)))
                 (curr (list-ref (lines m) row))
                 (merged (string-append prev curr))
                 (new-lines (append (take (lines m) (1- row))
                                    (list merged)
                                    (drop (lines m) (1+ row)))))
            (set! (lines m) new-lines)
            (set! (cursor-row m) (1- row))
            (set! (cursor-col m) (string-length prev))
            (grid-set-line! (grid-obj m) (1- row) merged "#aaa")
            (grid-set-line! (grid-obj m) row "" "#aaa")
            (grid-set-cursor! (grid-obj m) (string-length prev) (1- row))
            (values m #f)))
         (else (values m #f))))

       ;; Enter
       ((eq? k 'enter)
        (let* ((line (list-ref (lines m) row))
               (before (substring line 0 col))
               (after (substring line col))
               (new-lines (append (take (lines m) row)
                                  (list before after)
                                  (drop (lines m) (1+ row)))))
          (set! (lines m) new-lines)
          (set! (cursor-row m) (1+ row))
          (set! (cursor-col m) 0)
          (grid-set-line! (grid-obj m) row before "#aaa")
          (grid-set-line! (grid-obj m) (1+ row) after "#aaa")
          (grid-set-cursor! (grid-obj m) 0 (1+ row))
          (values m #f)))

       (else (values m #f)))))

   (else (values m #f))))

;;; View
(define (view m)
  (vbox
   (boxed (grid-render (grid-obj m) #t)
          #:border border-rounded
          #:fg "#666")
   (spacer 1)
   (txt (format #f "Line ~a/~a Col ~a | hjkl 0$ gG q"
                (1+ (cursor-row m))
                (length (lines m))
                (cursor-col m))
        #:fg "#888")))

;;; Run
(define model (make <model>
                #:lines '("Welcome to the grid-based editor!"
                          "hjkl or arrows to move"
                          "Type to insert, backspace to delete"
                          "0=start $=end g=first G=last"
                          "q to quit"
                          ""
                          "Start typing...")))

(run-app (make-app model (current-module)))
