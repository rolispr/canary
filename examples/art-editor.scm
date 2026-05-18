#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary app)
             (canary protocol)
             (canary component)
             (canary components canvas)
             (canary style)
             (canary text)
             (canary layout)
             (canary zones)
             (oop goops)
             (ice-9 receive)
             (ice-9 format)
             (srfi srfi-1))

(define nl "\n")

;;; Model
(define-class <model> ()
  (canvas #:init-value #f #:accessor canvas)
  (color-index #:init-value 0 #:accessor color-index)  ; Start with red
  (char-index #:init-value 9 #:accessor char-index))   ; Start with █

;;; Available colors
(define colors
  '("#ff0000" "#00ff00" "#0000ff" "#ffff00" "#ff00ff" "#00ffff"
    "#ffffff" "#888888" "#ff8800" "#88ff00" "#0088ff" "#ff0088"))

;;; Available characters for palette
(define char-palette
  '(#\space #\. #\: #\; #\+ #\= #\* #\# #\@ #\█ #\░ #\▒ #\▓ #\│ #\─ #\┌ #\┐ #\└ #\┘))

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

   ;; Clear canvas
   ((and (is-a? msg <key-msg>)
         (let ((k (key msg)))
           (and (char? k) (char=? k #\c))))
    (canvas-clear! (canvas m))
    (values m #f))

   ;; Palette selection
   ((and (is-a? msg <mouse-msg>) (eq? (action msg) 'press))
    (let ((char-zone (zone-get "char-palette"))
          (color-zone (zone-get "color-palette")))
      (cond
       ;; Click on character palette
       ((and char-zone (zone-in-bounds? char-zone msg))
        (receive (sx sy ex ey) (zone-coords char-zone)
          (let* ((rel-x (- (x msg) sx))
                 (idx (quotient rel-x 2)))
            (when (< idx (length char-palette))
              (set! (char-index m) idx)
              (set! (canvas-current-char (canvas m))
                    (list-ref char-palette idx)))
            (values m #f))))

       ;; Click on color palette
       ((and color-zone (zone-in-bounds? color-zone msg))
        (receive (sx sy ex ey) (zone-coords color-zone)
          (let* ((rel-x (- (x msg) sx))
                 (idx (quotient rel-x 2)))
            (when (< idx (length colors))
              (set! (color-index m) idx)
              (set! (canvas-current-fg (canvas m))
                    (list-ref colors idx)))
            (values m #f))))

       (else (values m #f)))))

   (else (values m #f))))

;;; View helpers
(define (render-char-palette m)
  "Render character palette with selection"
  (let ((parts '()))
    (do ((i 0 (1+ i)))
        ((>= i (length char-palette)))
      (let* ((ch (list-ref char-palette i))
             (selected? (= i (char-index m)))
             (display-str (string ch))
             (styled (if selected?
                        (bg (bold display-str) "#ffffff")
                        display-str)))
        (set! parts (cons styled parts))
        (when (< i (1- (length char-palette)))
          (set! parts (cons " " parts)))))
    (apply string-append (reverse parts))))

(define (render-color-palette m)
  "Render color palette with selection"
  (let ((parts '()))
    (do ((i 0 (1+ i)))
        ((>= i (length colors)))
      (let* ((color (list-ref colors i))
             (selected? (= i (color-index m)))
             (display-str "█")
             (styled (if selected?
                        (bold (fg display-str color))
                        (fg display-str color))))
        (set! parts (cons styled parts))
        (when (< i (1- (length colors)))
          (set! parts (cons " " parts)))))
    (apply string-append (reverse parts))))

;;; View
(define (view m)
  (let* ((char-pal (render-char-palette m))
         (color-pal (render-color-palette m))
         (canvas-obj (canvas m))
         (cx (canvas-cursor-x canvas-obj))
         (cy (canvas-cursor-y canvas-obj))
         (canvas-view-str (canvas-view canvas-obj))
         (status-line (format #f "Cursor: (~a,~a) | q=quit c=clear" cx cy)))
    (zone-scan
     (string-append "Char: " (zone-mark "char-palette" char-pal)
                    " | Color: " (zone-mark "color-palette" color-pal)
                    nl
                    status-line nl
                    (zone-mark "canvas" canvas-view-str)))))

;;; Run app
(define canvas-obj (make-canvas #:width 118 #:height 34 #:zone-id "canvas"))
(component-focus! canvas-obj)
(set! (canvas-current-char canvas-obj) (list-ref char-palette 9))  ; █
(set! (canvas-current-fg canvas-obj) "#ff0000")  ; Red

(define model (make <model>
                #:canvas canvas-obj
                #:color-index 0
                #:char-index 9))
(define user-module (current-module))
(run-app (make-app model user-module))
