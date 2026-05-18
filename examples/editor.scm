#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary app)
             (canary protocol)
             (canary style)
             (canary layout)
             (canary borders)
             (oop goops)
             (ice-9 format)
             (srfi srfi-1))

;;; Model
(define-class <model> ()
  (lines #:init-keyword #:lines #:init-value '("") #:accessor lines)
  (cursor-row #:init-value 0 #:accessor cursor-row)
  (cursor-col #:init-value 0 #:accessor cursor-col))

;;; Init
(define (init m) #f)

;;; Update
(define (update m msg)
  (cond
   ;; Quit
   ((and (is-a? msg <key-msg>)
         (let ((k (key msg)))
           (or (and (char? k) (char=? k #\q))
               (and (char? k) (char=? k #\Q)))))
    (values m (quit-cmd)))

   ;; Keys
   ((is-a? msg <key-msg>)
    (let ((k (key msg))
          (row (cursor-row m))
          (col (cursor-col m))
          (line-count (length (lines m))))
      (cond
       ;; Left / h
       ((or (eq? k 'left) (and (char? k) (char=? k #\h)))
        (when (> col 0) (set! (cursor-col m) (1- col)))
        (values m #f))

       ;; Down / j
       ((or (eq? k 'down) (and (char? k) (char=? k #\j)))
        (when (< row (1- line-count))
          (set! (cursor-row m) (1+ row))
          (let ((len (string-length (list-ref (lines m) (1+ row)))))
            (when (> col len) (set! (cursor-col m) len))))
        (values m #f))

       ;; Up / k
       ((or (eq? k 'up) (and (char? k) (char=? k #\k)))
        (when (> row 0)
          (set! (cursor-row m) (1- row))
          (let ((len (string-length (list-ref (lines m) (1- row)))))
            (when (> col len) (set! (cursor-col m) len))))
        (values m #f))

       ;; Right / l
       ((or (eq? k 'right) (and (char? k) (char=? k #\l)))
        (let ((len (string-length (list-ref (lines m) row))))
          (when (< col len) (set! (cursor-col m) (1+ col))))
        (values m #f))

       ;; Home / 0
       ((or (eq? k 'home) (and (char? k) (char=? k #\0)))
        (set! (cursor-col m) 0)
        (values m #f))

       ;; End / $
       ((or (eq? k 'end) (and (char? k) (char=? k #\$)))
        (set! (cursor-col m) (string-length (list-ref (lines m) row)))
        (values m #f))

       ;; First line / g
       ((and (char? k) (char=? k #\g))
        (set! (cursor-row m) 0)
        (values m #f))

       ;; Last line / G
       ((and (char? k) (char=? k #\G))
        (set! (cursor-row m) (1- line-count))
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
          (values m #f)))

       (else (values m #f)))))

   (else (values m #f))))

;;; View with terminal dimensions
(define (view m w h)
  (let* ((row (cursor-row m))
         (col (cursor-col m))
         (text-lines (lines m))
         (line-count (length text-lines))
         ;; Fill screen minus title, border, status
         (content-h (max 1 (- h 5)))
         (content-w (max 10 (- w 4)))
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
                             (width (string-append before (reverse-video (string ch)) after) content-w))
                           (width line content-w)))
                     (width "~" content-w #:fg "#666")))
               (iota content-h)))
         (status (format #f "Line ~a/~a Col ~a | ~ax~a | hjkl 0$ gG q"
                        (1+ row) line-count col w h)))

    (fullscreen
     (vbox
      (txt "Text Editor" #:bold? #t #:fg "#ff6b9d")
      (spacer 1)
      (boxed (apply vbox content-lines)
             #:border border-rounded
             #:fg "#666")
      (spacer 1)
      (txt status #:fg "#888"))
     w h)))

;;; Run
(define model (make <model>
                #:lines '("Welcome to the editor!"
                          "hjkl or arrows to move"
                          "Type to insert, backspace/enter"
                          "0=start $=end g=first G=last"
                          "q to quit"
                          ""
                          "Start typing...")))

(define app (make-app model (current-module)))
(run-app app)
