(define-module (canary draw)
  #:use-module (srfi srfi-9)
  #:export (<text-cmd>
            text-cmd?
            make-text
            text-col
            text-row
            text-str
            text-face
            text-attrs

            <fill-cmd>
            fill-cmd?
            make-fill
            fill-col
            fill-row
            fill-w
            fill-h
            fill-face

            <cursor-cmd>
            cursor-cmd?
            make-cursor
            cursor-col
            cursor-row
            cursor-style

            <clear-cmd>
            clear-cmd?
            make-clear

            cmd?))

(define-record-type <text-cmd>
  (make-text col row str face attrs)
  text-cmd?
  (col text-col)
  (row text-row)
  (str text-str)
  (face text-face)
  (attrs text-attrs))

(define-record-type <fill-cmd>
  (make-fill col row w h face)
  fill-cmd?
  (col fill-col)
  (row fill-row)
  (w fill-w)
  (h fill-h)
  (face fill-face))

(define-record-type <cursor-cmd>
  (make-cursor col row style)
  cursor-cmd?
  (col cursor-col)
  (row cursor-row)
  (style cursor-style))

(define-record-type <clear-cmd>
  (make-clear)
  clear-cmd?)

(define (cmd? x)
  (or (text-cmd? x) (fill-cmd? x) (cursor-cmd? x) (clear-cmd? x)))
