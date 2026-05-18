(define-module (canary view)
  #:use-module (srfi srfi-9)
  #:export (<rect>
            rect?
            make-rect
            rect-col
            rect-row
            rect-w
            rect-h
            rect-empty?

            view-node?
            view-size

            <text-node>
            text-node?
            make-text-node
            text-node-str
            text-node-face
            text-node-attrs

            <fill-node>
            fill-node?
            make-fill-node
            fill-node-w
            fill-node-h
            fill-node-face

            <spacer-node>
            spacer-node?
            make-spacer-node
            spacer-node-w
            spacer-node-h

            <vbox-node>
            vbox-node?
            make-vbox-node
            vbox-node-children

            <hbox-node>
            hbox-node?
            make-hbox-node
            hbox-node-children

            <boxed-node>
            boxed-node?
            make-boxed-node
            boxed-node-child
            boxed-node-border
            boxed-node-face

            <pad-node>
            pad-node?
            make-pad-node
            pad-node-child
            pad-node-top
            pad-node-right
            pad-node-bottom
            pad-node-left

            <align-node>
            align-node?
            make-align-node
            align-node-child
            align-node-mode
            align-node-width

            <width-node>
            width-node?
            make-width-node
            width-node-child
            width-node-w
            width-node-align

            <height-node>
            height-node?
            make-height-node
            height-node-child
            height-node-h
            height-node-valign

            <cursor-node>
            cursor-node?
            make-cursor-node
            cursor-node-col
            cursor-node-row
            cursor-node-style

            <overlay-node>
            overlay-node?
            make-overlay-node
            overlay-node-base
            overlay-node-overlays))

(define-record-type <rect>
  (make-rect col row w h)
  rect?
  (col rect-col)
  (row rect-row)
  (w rect-w)
  (h rect-h))

(define (rect-empty? r)
  (or (<= (rect-w r) 0) (<= (rect-h r) 0)))

(define-record-type <text-node>
  (make-text-node str face attrs)
  text-node?
  (str text-node-str)
  (face text-node-face)
  (attrs text-node-attrs))

(define-record-type <fill-node>
  (make-fill-node w h face)
  fill-node?
  (w fill-node-w)
  (h fill-node-h)
  (face fill-node-face))

(define-record-type <spacer-node>
  (make-spacer-node w h)
  spacer-node?
  (w spacer-node-w)
  (h spacer-node-h))

(define-record-type <vbox-node>
  (make-vbox-node children)
  vbox-node?
  (children vbox-node-children))

(define-record-type <hbox-node>
  (make-hbox-node children)
  hbox-node?
  (children hbox-node-children))

(define-record-type <boxed-node>
  (make-boxed-node child border face)
  boxed-node?
  (child boxed-node-child)
  (border boxed-node-border)
  (face boxed-node-face))

(define-record-type <pad-node>
  (make-pad-node child top right bottom left)
  pad-node?
  (child pad-node-child)
  (top pad-node-top)
  (right pad-node-right)
  (bottom pad-node-bottom)
  (left pad-node-left))

(define-record-type <align-node>
  (make-align-node child mode width)
  align-node?
  (child align-node-child)
  (mode align-node-mode)
  (width align-node-width))

(define-record-type <width-node>
  (make-width-node child w align)
  width-node?
  (child width-node-child)
  (w width-node-w)
  (align width-node-align))

(define-record-type <height-node>
  (make-height-node child h valign)
  height-node?
  (child height-node-child)
  (h height-node-h)
  (valign height-node-valign))

(define-record-type <cursor-node>
  (make-cursor-node col row style)
  cursor-node?
  (col cursor-node-col)
  (row cursor-node-row)
  (style cursor-node-style))

(define-record-type <overlay-node>
  (make-overlay-node base overlays)
  overlay-node?
  (base overlay-node-base)
  (overlays overlay-node-overlays))

(define (view-node? x)
  (or (text-node? x) (fill-node? x) (spacer-node? x)
      (vbox-node? x) (hbox-node? x) (boxed-node? x)
      (pad-node? x) (align-node? x)
      (width-node? x) (height-node? x)
      (cursor-node? x) (overlay-node? x)
      (string? x) (not x)))

(define (str-visible-length s)
  (string-length s))

(define (view-size node)
  (cond
   ((not node) (cons 0 0))
   ((string? node) (cons (string-length node) 1))
   ((text-node? node) (cons (str-visible-length (text-node-str node)) 1))
   ((fill-node? node) (cons (fill-node-w node) (fill-node-h node)))
   ((spacer-node? node) (cons (spacer-node-w node) (spacer-node-h node)))
   ((cursor-node? node) (cons 0 0))
   ((vbox-node? node)
    (let loop ((cs (vbox-node-children node)) (mw 0) (sh 0))
      (cond
       ((null? cs) (cons mw sh))
       (else
        (let ((s (view-size (car cs))))
          (loop (cdr cs) (max mw (car s)) (+ sh (cdr s))))))))
   ((hbox-node? node)
    (let loop ((cs (hbox-node-children node)) (sw 0) (mh 0))
      (cond
       ((null? cs) (cons sw mh))
       (else
        (let ((s (view-size (car cs))))
          (loop (cdr cs) (+ sw (car s)) (max mh (cdr s))))))))
   ((boxed-node? node)
    (let ((s (view-size (boxed-node-child node))))
      (cons (+ (car s) 2) (+ (cdr s) 2))))
   ((pad-node? node)
    (let ((s (view-size (pad-node-child node))))
      (cons (+ (car s) (pad-node-left node) (pad-node-right node))
            (+ (cdr s) (pad-node-top node) (pad-node-bottom node)))))
   ((align-node? node)
    (let ((s (view-size (align-node-child node))))
      (cons (or (align-node-width node) (car s)) (cdr s))))
   ((width-node? node)
    (let ((s (view-size (width-node-child node))))
      (cons (width-node-w node) (cdr s))))
   ((height-node? node)
    (let ((s (view-size (height-node-child node))))
      (cons (car s) (height-node-h node))))
   ((overlay-node? node) (view-size (overlay-node-base node)))
   (else (cons 0 0))))
