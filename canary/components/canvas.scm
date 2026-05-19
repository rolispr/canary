;;; components/canvas.scm --- Editable 2D canvas for ASCII/ANSI art

(define-module (canary components canvas)
  #:use-module (canary protocol)
  #:use-module (canary component)
  #:use-module (canary style)
  #:use-module (canary text)
  #:use-module (canary zones)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:export (make-canvas
            canvas-width
            canvas-height
            canvas-cursor-x
            canvas-cursor-y
            canvas-current-char
            canvas-current-fg
            canvas-current-bg
            canvas-set!
            canvas-get
            canvas-clear!
            canvas-view
            <canvas>))

;;; Cell record
(define-class <cell> ()
  (char #:init-keyword #:char #:init-value #\space #:accessor cell-char)
  (fg #:init-keyword #:fg #:init-value #f #:accessor cell-fg)
  (bg #:init-keyword #:bg #:init-value #f #:accessor cell-bg))

;;; Canvas class
(define-class <canvas> (<component>)
  (width #:init-keyword #:width #:init-value 40 #:accessor canvas-width)
  (height #:init-keyword #:height #:init-value 20 #:accessor canvas-height)
  (grid #:accessor canvas-grid)
  (cursor-x #:init-value 0 #:accessor canvas-cursor-x)
  (cursor-y #:init-value 0 #:accessor canvas-cursor-y)
  (current-char #:init-value #\█ #:accessor canvas-current-char)
  (current-fg #:init-value "#ffffff" #:accessor canvas-current-fg)
  (current-bg #:init-value #f #:accessor canvas-current-bg)
  (zone-id #:init-keyword #:zone-id #:init-value #f #:accessor canvas-zone-id))

(define* (make-canvas #:key (width 40) (height 20) (zone-id "canvas"))
  "Create a new canvas"
  (let ((c (make <canvas> #:width width #:height height #:zone-id zone-id)))
    (set! (canvas-grid c) (make-vector height))
    (do ((y 0 (1+ y)))
        ((>= y height))
      (let ((row (make-vector width)))
        (do ((x 0 (1+ x)))
            ((>= x width))
          (vector-set! row x (make <cell>)))
        (vector-set! (canvas-grid c) y row)))
    c))

;;; Grid operations
(define (canvas-get canvas x y)
  "Get cell at position"
  (if (and (>= x 0) (< x (canvas-width canvas))
           (>= y 0) (< y (canvas-height canvas)))
      (vector-ref (vector-ref (canvas-grid canvas) y) x)
      #f))

(define (canvas-set! canvas x y char fg bg)
  "Set cell at position"
  (when (and (>= x 0) (< x (canvas-width canvas))
             (>= y 0) (< y (canvas-height canvas)))
    (let ((cell (canvas-get canvas x y)))
      (when cell
        (set! (cell-char cell) char)
        (set! (cell-fg cell) fg)
        (set! (cell-bg cell) bg)))))

(define (canvas-clear! canvas)
  "Clear entire canvas"
  (do ((y 0 (1+ y)))
      ((>= y (canvas-height canvas)))
    (do ((x 0 (1+ x)))
        ((>= x (canvas-width canvas)))
      (canvas-set! canvas x y #\space #f #f))))

(define (canvas-paint-at! canvas x y)
  "Paint current char/color at position"
  (canvas-set! canvas x y
               (canvas-current-char canvas)
               (canvas-current-fg canvas)
               (canvas-current-bg canvas)))

;;; Update
(define (canvas-update canvas msg)
  "Update canvas with message"
  (cond
   ;; Mouse click or drag - paint
   ((and (mouse? msg)
         (or (eq? (mouse-action msg) 'press)
             (eq? (mouse-action msg) 'drag)))
    (let* ((zone-id (canvas-zone-id canvas))
           (zone (and zone-id (zone-get zone-id))))
      (if (and zone (zone-in-bounds? zone msg))
          (receive (zx zy zex zey) (zone-coords zone)
            (let* ((grid-x (- (mouse-x msg) zx))
                   (grid-y (- (mouse-y msg) zy)))
              (if (and (>= grid-x 0) (< grid-x (canvas-width canvas))
                       (>= grid-y 0) (< grid-y (canvas-height canvas)))
                  (begin
                    (set! (canvas-cursor-x canvas) grid-x)
                    (set! (canvas-cursor-y canvas) grid-y)
                    (canvas-paint-at! canvas grid-x grid-y)
                    (values canvas #t))
                  (values canvas #f))))
          (values canvas #f))))

   ;; Not focused - don't handle
   ((not (component-focused? canvas))
    (values canvas #f))

   ;; Key messages
   ((key? msg)
    (let ((k (key-char msg)))
      (match k
        ('up
         (when (> (canvas-cursor-y canvas) 0)
           (set! (canvas-cursor-y canvas) (1- (canvas-cursor-y canvas))))
         (values canvas #t))

        ('down
         (when (< (canvas-cursor-y canvas) (1- (canvas-height canvas)))
           (set! (canvas-cursor-y canvas) (1+ (canvas-cursor-y canvas))))
         (values canvas #t))

        ('left
         (when (> (canvas-cursor-x canvas) 0)
           (set! (canvas-cursor-x canvas) (1- (canvas-cursor-x canvas))))
         (values canvas #t))

        ('right
         (when (< (canvas-cursor-x canvas) (1- (canvas-width canvas)))
           (set! (canvas-cursor-x canvas) (1+ (canvas-cursor-x canvas))))
         (values canvas #t))

        ('enter
         (canvas-paint-at! canvas (canvas-cursor-x canvas) (canvas-cursor-y canvas))
         (values canvas #t))

        ('backspace
         (canvas-set! canvas (canvas-cursor-x canvas) (canvas-cursor-y canvas)
                      #\space #f #f)
         (values canvas #t))

        (_
         (values canvas #f)))))

   (else (values canvas #f))))

;;; Component protocol
(define-method (react (canvas <canvas>) msg)
  "Handle messages via component protocol"
  (canvas-update canvas msg))

;;; View
(define (canvas-view canvas)
  "Render canvas to ANSI string"
  (let ((grid (canvas-grid canvas))
        (width (canvas-width canvas))
        (height (canvas-height canvas))
        (cursor-x (canvas-cursor-x canvas))
        (cursor-y (canvas-cursor-y canvas))
        (focused (component-focused? canvas))
        (zone-id (canvas-zone-id canvas))
        (lines '()))

    (do ((y 0 (1+ y)))
        ((>= y height))
      (let ((line-parts '()))
        (do ((x 0 (1+ x)))
            ((>= x width))
          (let* ((cell (canvas-get canvas x y))
                 (ch (if cell (cell-char cell) #\space))
                 (fg-color (if cell (cell-fg cell) #f))
                 (bg-color (if cell (cell-bg cell) #f))
                 (is-cursor? (and focused (= x cursor-x) (= y cursor-y)))
                 (styled (cond
                          (is-cursor?
                           (reverse-video (string ch)))
                          ((and fg-color bg-color)
                           (bg (fg (string ch) fg-color) bg-color))
                          (fg-color
                           (fg (string ch) fg-color))
                          (bg-color
                           (bg (string ch) bg-color))
                          (else
                           (string ch)))))
            (set! line-parts (cons styled line-parts))))
        (set! lines (cons (apply string-append (reverse line-parts)) lines))))

    (string-join (reverse lines) nl)))
