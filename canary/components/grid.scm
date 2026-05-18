;;; grid.scm --- 2D character grid for efficient rendering and editing

(define-module (canary components grid)
  #:use-module (oop goops)
  #:use-module (canary component)
  #:use-module (canary protocol)
  #:use-module (canary style)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:export (<grid>
            make-grid
            grid-width
            grid-height
            grid-get
            grid-set!
            grid-get-line
            grid-set-line!
            grid-clear!
            grid-fill!
            grid-insert-line!
            grid-delete-line!
            grid-render
            grid-cursor-x
            grid-cursor-y
            grid-set-cursor!))

;;; Cell structure: (char . fg-color)
(define (make-cell char fg)
  (cons char fg))

(define (cell-char cell) (car cell))
(define (cell-fg cell) (cdr cell))

;;; Grid component
(define-class <grid> (<component>)
  (width #:init-keyword #:width #:init-value 80 #:accessor grid-width)
  (height #:init-keyword #:height #:init-value 24 #:accessor grid-height)
  (cells #:init-value #f #:accessor grid-cells)
  (cursor-x #:init-value 0 #:accessor grid-cursor-x)
  (cursor-y #:init-value 0 #:accessor grid-cursor-y)
  (default-char #:init-keyword #:default-char #:init-value #\space #:accessor grid-default-char)
  (default-fg #:init-keyword #:default-fg #:init-value #f #:accessor grid-default-fg))

(define-method (initialize (g <grid>) initargs)
  (next-method)
  (let ((w (grid-width g))
        (h (grid-height g))
        (ch (grid-default-char g))
        (fg (grid-default-fg g)))
    ;; Initialize cells as vector of vectors
    (set! (grid-cells g)
          (make-vector h
                      (make-vector w (make-cell ch fg))))
    ;; Make each row independent
    (do ((i 0 (1+ i)))
        ((>= i h))
      (vector-set! (grid-cells g) i
                   (make-vector w (make-cell ch fg))))))

(define* (make-grid #:key (width 80) (height 24) (default-char #\space) (default-fg #f))
  "Create a new character grid"
  (make <grid>
    #:width width
    #:height height
    #:default-char default-char
    #:default-fg default-fg))

(define-method (grid-get (g <grid>) x y)
  "Get cell at (x, y). Returns (char . fg) or #f if out of bounds"
  (if (and (>= x 0) (< x (grid-width g))
           (>= y 0) (< y (grid-height g)))
      (vector-ref (vector-ref (grid-cells g) y) x)
      #f))

(define-method (grid-set! (g <grid>) x y char . args)
  "Set character at (x, y) with optional foreground color"
  (when (and (>= x 0) (< x (grid-width g))
             (>= y 0) (< y (grid-height g)))
    (let* ((fg (if (pair? args) (car args) (grid-default-fg g)))
           (row (vector-ref (grid-cells g) y)))
      (vector-set! row x (make-cell char fg)))))

(define-method (grid-get-line (g <grid>) y)
  "Get entire line y as a string"
  (if (and (>= y 0) (< y (grid-height g)))
      (let ((row (vector-ref (grid-cells g) y)))
        (list->string
         (map (lambda (i) (cell-char (vector-ref row i)))
              (iota (grid-width g)))))
      ""))

(define-method (grid-set-line! (g <grid>) y text . args)
  "Set entire line y from text string, with optional foreground color"
  (when (and (>= y 0) (< y (grid-height g)))
    (let ((fg (if (pair? args) (car args) (grid-default-fg g)))
          (row (vector-ref (grid-cells g) y))
          (len (min (string-length text) (grid-width g))))
      ;; Copy text characters
      (do ((i 0 (1+ i)))
          ((>= i len))
        (vector-set! row i (make-cell (string-ref text i) fg)))
      ;; Fill rest with default
      (do ((i len (1+ i)))
          ((>= i (grid-width g)))
        (vector-set! row i (make-cell (grid-default-char g) (grid-default-fg g)))))))

(define-method (grid-clear! (g <grid>))
  "Clear entire grid to default character"
  (let ((ch (grid-default-char g))
        (fg (grid-default-fg g))
        (default-cell (make-cell ch fg)))
    (do ((y 0 (1+ y)))
        ((>= y (grid-height g)))
      (let ((row (vector-ref (grid-cells g) y)))
        (do ((x 0 (1+ x)))
            ((>= x (grid-width g)))
          (vector-set! row x default-cell))))))

(define-method (grid-fill! (g <grid>) char . args)
  "Fill entire grid with character and optional color"
  (let* ((fg (if (pair? args) (car args) (grid-default-fg g)))
         (cell (make-cell char fg)))
    (do ((y 0 (1+ y)))
        ((>= y (grid-height g)))
      (let ((row (vector-ref (grid-cells g) y)))
        (do ((x 0 (1+ x)))
            ((>= x (grid-width g)))
          (vector-set! row x cell))))))

(define-method (grid-insert-line! (g <grid>) y . args)
  "Insert a blank line at y, shifting lines down (bottom line is lost)"
  (when (and (>= y 0) (< y (grid-height g)))
    (let ((text (if (pair? args) (car args) ""))
          (fg (if (and (pair? args) (pair? (cdr args)))
                  (cadr args)
                  (grid-default-fg g))))
      ;; Shift lines down
      (do ((i (1- (grid-height g)) (1- i)))
          ((< i (1+ y)))
        (vector-set! (grid-cells g) i
                    (vector-ref (grid-cells g) (1- i))))
      ;; Create new line
      (let ((new-row (make-vector (grid-width g)
                                  (make-cell (grid-default-char g) (grid-default-fg g)))))
        (vector-set! (grid-cells g) y new-row)
        (when (> (string-length text) 0)
          (grid-set-line! g y text fg))))))

(define-method (grid-delete-line! (g <grid>) y)
  "Delete line at y, shifting lines up (new blank line at bottom)"
  (when (and (>= y 0) (< y (grid-height g)))
    ;; Shift lines up
    (do ((i y (1+ i)))
        ((>= i (1- (grid-height g))))
      (vector-set! (grid-cells g) i
                  (vector-ref (grid-cells g) (1+ i))))
    ;; Create new blank line at bottom
    (let ((new-row (make-vector (grid-width g)
                                (make-cell (grid-default-char g)
                                          (grid-default-fg g)))))
      (vector-set! (grid-cells g) (1- (grid-height g)) new-row))))

(define-method (grid-set-cursor! (g <grid>) x y)
  "Set cursor position"
  (set! (grid-cursor-x g) (max 0 (min x (1- (grid-width g)))))
  (set! (grid-cursor-y g) (max 0 (min y (1- (grid-height g))))))

(define-method (grid-render (g <grid>) . args)
  "Render grid to string with optional cursor highlighting"
  (let ((show-cursor? (if (pair? args) (car args) #f))
        (cx (grid-cursor-x g))
        (cy (grid-cursor-y g))
        (lines '()))
    (do ((y 0 (1+ y)))
        ((>= y (grid-height g)))
      (let ((parts '())
            (row (vector-ref (grid-cells g) y)))
        (do ((x 0 (1+ x)))
            ((>= x (grid-width g)))
          (let* ((cell (vector-ref row x))
                 (ch (cell-char cell))
                 (fg-color (cell-fg cell))
                 (is-cursor? (and show-cursor? (= x cx) (= y cy)))
                 (char-str (string ch))
                 (styled (cond
                         (is-cursor?
                          (reverse-video char-str))
                         (fg-color
                          (fg char-str fg-color))
                         (else char-str))))
            (set! parts (cons styled parts))))
        (set! lines (cons (apply string-append (reverse parts)) lines))))
    (string-join (reverse lines) "\n")))
