#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary app)
             (canary protocol)
             (canary style)
             ((canary layout) #:select (vbox width))
             (canary text)
             (oop goops)
             (ice-9 format)
             (srfi srfi-1))

;;; Model
(define-class <model> ()
  (lines #:init-keyword #:lines #:init-value '("") #:accessor lines)
  (cursor-row #:init-value 0 #:accessor cursor-row)
  (cursor-col #:init-value 0 #:accessor cursor-col)
  (win-width #:init-value 80 #:accessor win-width)
  (win-height #:init-value 24 #:accessor win-height))

(define (init m) #f)

(define (update m msg)
  (format (current-error-port) "UPDATE: ~a~%" msg)
  (cond
   ((is-a? msg <window-size-msg>)
    (format (current-error-port) "  -> window size~%")
    (set! (win-width m) (slot-ref msg 'width))
    (set! (win-height m) (slot-ref msg 'height))
    (values m #f))

   ((and (is-a? msg <key-msg>) (char? (key msg)) (member (key msg) '(#\q #\Q)))
    (values m (quit-cmd)))

   ((is-a? msg <key-msg>)
    (let ((k (key msg))
          (row (cursor-row m))
          (col (cursor-col m))
          (line-count (length (lines m))))
      (cond
       ((or (eq? k 'left) (and (char? k) (char=? k #\h)))
        (when (> col 0) (set! (cursor-col m) (1- col)))
        (values m #f))

       ((or (eq? k 'down) (and (char? k) (char=? k #\j)))
        (when (< row (1- line-count))
          (set! (cursor-row m) (1+ row))
          (let ((len (string-length (list-ref (lines m) (1+ row)))))
            (when (> col len) (set! (cursor-col m) len))))
        (values m #f))

       ((or (eq? k 'up) (and (char? k) (char=? k #\k)))
        (when (> row 0)
          (set! (cursor-row m) (1- row))
          (let ((len (string-length (list-ref (lines m) (1- row)))))
            (when (> col len) (set! (cursor-col m) len))))
        (values m #f))

       ((or (eq? k 'right) (and (char? k) (char=? k #\l)))
        (let ((len (string-length (list-ref (lines m) row))))
          (when (< col len) (set! (cursor-col m) (1+ col))))
        (values m #f))

       ((and (char? k) (char=? k #\0))
        (set! (cursor-col m) 0)
        (values m #f))

       ((and (char? k) (char=? k #\$))
        (set! (cursor-col m) (string-length (list-ref (lines m) row)))
        (values m #f))

       ((and (char? k) (char=? k #\g))
        (set! (cursor-row m) 0)
        (values m #f))

       ((and (char? k) (char=? k #\G))
        (set! (cursor-row m) (1- line-count))
        (values m #f))

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
          (values m #f)))

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
            (values m #f)))
         (else (values m #f))))

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
          (values m #f)))

       (else (values m #f)))))

   (else (values m #f))))

(define (view m)
  (let* ((w (win-width m))
         (h (win-height m))
         (row (cursor-row m))
         (col (cursor-col m))
         (text-lines (lines m))
         (line-count (length text-lines))
         (content-h (max 1 (- h 3)))
         (border-w (max 10 (- w 4)))

         ;; Build content lines
         (content-lines
          (map (lambda (i)
                 (if (< i line-count)
                     (let* ((line (list-ref text-lines i))
                            (is-cursor? (= i row)))
                       (if is-cursor?
                           (let* ((before (substring line 0 (min col (string-length line))))
                                  (ch (if (< col (string-length line))
                                          (string-ref line col)
                                          #\space))
                                  (after (if (< (1+ col) (string-length line))
                                             (substring line (1+ col))
                                             "")))
                             (string-append before (reverse-video (string ch)) after))
                           line))
                     "~"))
               (iota content-h)))

         (top-border (string-append "┌" (make-string border-w #\─) "┐"))
         (bottom-border (string-append "└" (make-string border-w #\─) "┘"))
         (status (format #f "Line ~a/~a Col ~a | hjkl 0$ gG q" (1+ row) line-count col)))

    (vbox
     top-border
     (apply vbox
            (map (lambda (line)
                   (string-append "│ " (width line border-w) " │"))
                 content-lines))
     bottom-border
     status)))

(define model (make <model>
                #:lines '("Welcome to the text editor!"
                          "hjkl or arrows to move"
                          "Type to insert, backspace to delete"
                          "0=start $=end g=first G=last"
                          "q to quit"
                          ""
                          "Start typing...")))

(run-app (make-app model (current-module)))
