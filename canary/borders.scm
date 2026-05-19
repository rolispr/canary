(define-module (canary borders)
  #:use-module (canary view)
  #:use-module (srfi srfi-9)
  #:export (<border>
            border?
            make-border
            border-top
            border-bottom
            border-left
            border-right
            border-tl
            border-tr
            border-bl
            border-br
            border-normal
            border-rounded
            border-thick
            border-double
            border-ascii
            boxed))

(define-record-type <border>
  (make-border top bottom left right tl tr bl br)
  border?
  (top border-top)
  (bottom border-bottom)
  (left border-left)
  (right border-right)
  (tl border-tl)
  (tr border-tr)
  (bl border-bl)
  (br border-br))

(define border-normal
  (make-border "─" "─" "│" "│" "┌" "┐" "└" "┘"))

(define border-rounded
  (make-border "─" "─" "│" "│" "╭" "╮" "╰" "╯"))

(define border-thick
  (make-border "━" "━" "┃" "┃" "┏" "┓" "┗" "┛"))

(define border-double
  (make-border "═" "═" "║" "║" "╔" "╗" "╚" "╝"))

(define border-ascii
  (make-border "-" "-" "|" "|" "+" "+" "+" "+"))

(define* (boxed child #:key (border border-normal) (face #f))
  (make-boxed-node child border face))
