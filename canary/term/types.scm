(define-module (canary term types)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-9 gnu)
  #:export (<face-attrs>
            make-face-attrs
            face-attrs?
            face-fg set-face-fg!
            face-bg set-face-bg!
            face-bold? set-face-bold!
            face-faint? set-face-faint!
            face-italic? set-face-italic!
            face-underline set-face-underline!
            face-ul-color set-face-ul-color!
            face-blink set-face-blink!
            face-inverse? set-face-inverse!
            face-conceal? set-face-conceal!
            face-crossed? set-face-crossed!
            default-face-attrs
            copy-face-attrs
            face-attrs-equal?
            reset-face-attrs!

            <cell>
            make-cell
            cell?
            cell-char set-cell-char!
            cell-face set-cell-face!

            <term>
            make-term
            term?
            term-width set-term-width!
            term-height set-term-height!
            term-grid set-term-grid!
            term-alt-grid set-term-alt-grid!
            term-main-grid set-term-main-grid!
            term-cursor-x set-term-cursor-x!
            term-cursor-y set-term-cursor-y!
            term-saved-cursor-x set-term-saved-cursor-x!
            term-saved-cursor-y set-term-saved-cursor-y!
            term-saved-attrs set-term-saved-attrs!
            term-attrs set-term-attrs!
            term-scroll-top set-term-scroll-top!
            term-scroll-bottom set-term-scroll-bottom!
            term-parser-state set-term-parser-state!
            term-csi-params set-term-csi-params!
            term-csi-format set-term-csi-format!
            term-osc-buf set-term-osc-buf!
            term-auto-margin? set-term-auto-margin!
            term-insert? set-term-insert!
            term-keypad? set-term-keypad!
            term-bracketed-paste? set-term-bracketed-paste!
            term-cursor-visible? set-term-cursor-visible!
            term-cursor-style set-term-cursor-style!
            term-g0 set-term-g0!
            term-g1 set-term-g1!
            term-g2 set-term-g2!
            term-g3 set-term-g3!
            term-active-charset set-term-active-charset!
            term-scrollback set-term-scrollback!
            term-scrollback-size set-term-scrollback-size!
            term-max-scrollback
            term-input-fn set-term-input-fn!
            term-bell-fn set-term-bell-fn!
            term-title-fn set-term-title-fn!
            term-cwd-fn set-term-cwd-fn!
            term-title set-term-title!
            term-cwd set-term-cwd!
            term-last-char set-term-last-char!
            term-in-alt? set-term-in-alt!
            term-last-write-face set-term-last-write-face!

            term-grid-row
            term-grid-cell
            set-term-grid-cell!
            make-grid
            make-row
            clear-row!
            clear-grid!
            copy-row
            term-reset!
            term-resize!))

(define-record-type <face-attrs>
  (%make-face-attrs fg bg bold? faint? italic? underline ul-color
                    blink inverse? conceal? crossed?)
  face-attrs?
  (fg          face-fg          set-face-fg!)
  (bg          face-bg          set-face-bg!)
  (bold?       face-bold?       set-face-bold!)
  (faint?      face-faint?      set-face-faint!)
  (italic?     face-italic?     set-face-italic!)
  (underline   face-underline   set-face-underline!)
  (ul-color    face-ul-color    set-face-ul-color!)
  (blink       face-blink       set-face-blink!)
  (inverse?    face-inverse?    set-face-inverse!)
  (conceal?    face-conceal?    set-face-conceal!)
  (crossed?    face-crossed?    set-face-crossed!))

(define* (make-face-attrs #:key (fg #f) (bg #f) (bold? #f) (faint? #f)
                          (italic? #f) (underline #f) (ul-color #f)
                          (blink #f) (inverse? #f) (conceal? #f)
                          (crossed? #f))
  (%make-face-attrs fg bg bold? faint? italic? underline ul-color
                    blink inverse? conceal? crossed?))

(define (default-face-attrs)
  (%make-face-attrs #f #f #f #f #f #f #f #f #f #f #f))

(define (copy-face-attrs f)
  (%make-face-attrs (face-fg f) (face-bg f) (face-bold? f)
                    (face-faint? f) (face-italic? f) (face-underline f)
                    (face-ul-color f) (face-blink f) (face-inverse? f)
                    (face-conceal? f) (face-crossed? f)))

(define (face-attrs-equal? a b)
  (cond
   ((and (not a) (not b)) #t)
   ((or (not a) (not b)) #f)
   (else
    (and (equal? (face-fg a) (face-fg b))
         (equal? (face-bg a) (face-bg b))
         (eq? (face-bold? a) (face-bold? b))
         (eq? (face-faint? a) (face-faint? b))
         (eq? (face-italic? a) (face-italic? b))
         (equal? (face-underline a) (face-underline b))
         (equal? (face-ul-color a) (face-ul-color b))
         (equal? (face-blink a) (face-blink b))
         (eq? (face-inverse? a) (face-inverse? b))
         (eq? (face-conceal? a) (face-conceal? b))
         (eq? (face-crossed? a) (face-crossed? b))))))

(define (reset-face-attrs! f)
  (set-face-fg! f #f)
  (set-face-bg! f #f)
  (set-face-bold! f #f)
  (set-face-faint! f #f)
  (set-face-italic! f #f)
  (set-face-underline! f #f)
  (set-face-ul-color! f #f)
  (set-face-blink! f #f)
  (set-face-inverse! f #f)
  (set-face-conceal! f #f)
  (set-face-crossed! f #f))

(define-record-type <cell>
  (%make-cell ch face)
  cell?
  (ch    cell-char  set-cell-char!)
  (face  cell-face  set-cell-face!))

(define* (make-cell #:optional (ch #\space) (face #f))
  (%make-cell ch face))

(define (make-row width)
  (let ((row (make-vector width #f)))
    (do ((x 0 (+ x 1)))
        ((= x width) row)
      (vector-set! row x (make-cell)))))

(define (make-grid width height)
  (let ((grid (make-vector height #f)))
    (do ((y 0 (+ y 1)))
        ((= y height) grid)
      (vector-set! grid y (make-row width)))))

(define (clear-row! row . maybe-face)
  (let ((face (if (pair? maybe-face) (car maybe-face) #f))
        (len (vector-length row)))
    (do ((x 0 (+ x 1)))
        ((= x len))
      (let ((c (vector-ref row x)))
        (set-cell-char! c #\space)
        (set-cell-face! c face)))))

(define (clear-grid! grid . maybe-face)
  (let ((face (if (pair? maybe-face) (car maybe-face) #f))
        (h (vector-length grid)))
    (do ((y 0 (+ y 1)))
        ((= y h))
      (clear-row! (vector-ref grid y) face))))

(define (copy-row src)
  (let* ((len (vector-length src))
         (dst (make-vector len #f)))
    (do ((x 0 (+ x 1)))
        ((= x len) dst)
      (let ((sc (vector-ref src x)))
        (vector-set! dst x (make-cell (cell-char sc) (cell-face sc)))))))

(define-record-type <term>
  (%make-term width height grid alt-grid main-grid
              cx cy saved-cx saved-cy saved-attrs attrs
              scroll-top scroll-bottom
              parser-state csi-params csi-format osc-buf
              auto-margin? insert? keypad? bracketed-paste?
              cursor-visible? cursor-style
              g0 g1 g2 g3 active-charset
              scrollback scrollback-size max-scrollback
              input-fn bell-fn title-fn cwd-fn
              title cwd last-char in-alt?
              last-write-face)
  term?
  (width            term-width            set-term-width!)
  (height           term-height           set-term-height!)
  (grid             term-grid             set-term-grid!)
  (alt-grid         term-alt-grid         set-term-alt-grid!)
  (main-grid        term-main-grid        set-term-main-grid!)
  (cx               term-cursor-x         set-term-cursor-x!)
  (cy               term-cursor-y         set-term-cursor-y!)
  (saved-cx         term-saved-cursor-x   set-term-saved-cursor-x!)
  (saved-cy         term-saved-cursor-y   set-term-saved-cursor-y!)
  (saved-attrs      term-saved-attrs      set-term-saved-attrs!)
  (attrs            term-attrs            set-term-attrs!)
  (scroll-top       term-scroll-top       set-term-scroll-top!)
  (scroll-bottom    term-scroll-bottom    set-term-scroll-bottom!)
  (parser-state     term-parser-state     set-term-parser-state!)
  (csi-params       term-csi-params       set-term-csi-params!)
  (csi-format       term-csi-format       set-term-csi-format!)
  (osc-buf          term-osc-buf          set-term-osc-buf!)
  (auto-margin?     term-auto-margin?     set-term-auto-margin!)
  (insert?          term-insert?          set-term-insert!)
  (keypad?          term-keypad?          set-term-keypad!)
  (bracketed-paste? term-bracketed-paste? set-term-bracketed-paste!)
  (cursor-visible?  term-cursor-visible?  set-term-cursor-visible!)
  (cursor-style     term-cursor-style     set-term-cursor-style!)
  (g0               term-g0               set-term-g0!)
  (g1               term-g1               set-term-g1!)
  (g2               term-g2               set-term-g2!)
  (g3               term-g3               set-term-g3!)
  (active-charset   term-active-charset   set-term-active-charset!)
  (scrollback       term-scrollback       set-term-scrollback!)
  (scrollback-size  term-scrollback-size  set-term-scrollback-size!)
  (max-scrollback   term-max-scrollback)
  (input-fn         term-input-fn         set-term-input-fn!)
  (bell-fn          term-bell-fn          set-term-bell-fn!)
  (title-fn         term-title-fn         set-term-title-fn!)
  (cwd-fn           term-cwd-fn           set-term-cwd-fn!)
  (title            term-title            set-term-title!)
  (cwd              term-cwd              set-term-cwd!)
  (last-char        term-last-char        set-term-last-char!)
  (in-alt?          term-in-alt?          set-term-in-alt!)
  (last-write-face  term-last-write-face  set-term-last-write-face!))

(define* (make-term #:key (width 80) (height 24)
                    (input-fn #f) (bell-fn #f)
                    (title-fn #f) (cwd-fn #f)
                    (max-scrollback 10000))
  (%make-term width height
              (make-grid width height) #f #f
              0 0 0 0 (default-face-attrs) (default-face-attrs)
              0 (- height 1)
              #f '() #f ""
              #t #f #f #f
              #t 'block
              'us-ascii 'us-ascii 'us-ascii 'us-ascii 'g0
              (if (positive? max-scrollback)
                  (make-vector 64 #f)
                  #f)
              0 max-scrollback
              input-fn bell-fn title-fn cwd-fn
              "" "" #\space #f
              #f))

(define (term-grid-row t y)
  (vector-ref (term-grid t) y))

(define (term-grid-cell t x y)
  (vector-ref (term-grid-row t y) x))

(define (set-term-grid-cell! t x y cell)
  (vector-set! (term-grid-row t y) x cell))

(define (term-reset! t)
  (set-term-parser-state! t #f)
  (set-term-csi-params! t '())
  (set-term-csi-format! t #f)
  (set-term-osc-buf! t "")
  (set-term-cursor-x! t 0)
  (set-term-cursor-y! t 0)
  (set-term-scroll-top! t 0)
  (set-term-scroll-bottom! t (- (term-height t) 1))
  (set-term-auto-margin! t #t)
  (set-term-insert! t #f)
  (set-term-keypad! t #f)
  (set-term-bracketed-paste! t #f)
  (set-term-cursor-visible! t #t)
  (set-term-cursor-style! t 'block)
  (set-term-active-charset! t 'g0)
  (set-term-g0! t 'us-ascii)
  (set-term-g1! t 'us-ascii)
  (set-term-g2! t 'us-ascii)
  (set-term-g3! t 'us-ascii)
  (reset-face-attrs! (term-attrs t))
  (clear-grid! (term-grid t))
  (when (term-in-alt? t)
    (set-term-grid! t (term-main-grid t))
    (set-term-main-grid! t #f)
    (set-term-in-alt! t #f)))

(define (term-resize! t cols rows)
  (when (and (positive? cols) (positive? rows)
             (or (not (= cols (term-width t)))
                 (not (= rows (term-height t)))))
    (let ((old-grid (term-grid t))
          (old-w (term-width t))
          (old-h (term-height t))
          (new-grid (make-grid cols rows)))
      (let ((copy-h (min old-h rows))
            (copy-w (min old-w cols)))
        (do ((y 0 (+ y 1)))
            ((= y copy-h))
          (let ((src-row (vector-ref old-grid y))
                (dst-row (vector-ref new-grid y)))
            (do ((x 0 (+ x 1)))
                ((= x copy-w))
              (let ((sc (vector-ref src-row x))
                    (dc (vector-ref dst-row x)))
                (set-cell-char! dc (cell-char sc))
                (set-cell-face! dc (cell-face sc)))))))
      (set-term-grid! t new-grid)
      (set-term-width! t cols)
      (set-term-height! t rows)
      (set-term-scroll-top! t 0)
      (set-term-scroll-bottom! t (- rows 1))
      (set-term-cursor-x! t (min (term-cursor-x t) (- cols 1)))
      (set-term-cursor-y! t (min (term-cursor-y t) (- rows 1)))
      (when (term-in-alt? t)
        (let ((old-main (term-main-grid t))
              (new-main (make-grid cols rows)))
          (when old-main
            (let ((copy-h (min (vector-length old-main) rows)))
              (do ((y 0 (+ y 1)))
                  ((= y copy-h))
                (let* ((src-row (vector-ref old-main y))
                       (dst-row (vector-ref new-main y))
                       (copy-w (min (vector-length src-row) cols)))
                  (do ((x 0 (+ x 1)))
                      ((= x copy-w))
                    (let ((sc (vector-ref src-row x))
                          (dc (vector-ref dst-row x)))
                      (set-cell-char! dc (cell-char sc))
                      (set-cell-face! dc (cell-face sc))))))))
          (set-term-main-grid! t new-main))))))
