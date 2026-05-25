(add-to-load-path (string-append (dirname (current-filename)) "/.."))

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (canary node)
             (canary view)
             (canary layout)
             (canary protocol)
             (canary render)
             (canary draw))

(test-begin "engine")

;; Pull cascade-related helpers directly. They're internal to (canary
;; engine) so we instead test through public API: walk-statefuls is
;; the foundation; we exercise it via a tracking node.

;; A node that records every msg it receives via its react proc.
(define-node tape
  #:state ((seen '()))
  #:view  (lambda (t) (txt "tape"))
  #:react (lambda (t msg)
            (set! (tape-seen t) (cons msg (tape-seen t)))
            #f))

;; A node that returns a cmd from its first react.
(define-node ticker-installer
  #:state ((installed? #f))
  #:view  (lambda (n) (txt "tk"))
  #:react (lambda (n msg)
            (cond
             ((init? msg)
              (set! (ticker-installer-installed? n) #t)
              ;; pretend cmd — would be (every #:hz 60 ...) in real code
              'pretend-cmd)
             (else #f))))

;; A node that only sees ticks via subscribes.
(define-node tick-only
  #:state ((count 0))
  #:subscribes (tick?)
  #:view  (lambda (n) (txt (number->string (tick-only-count n))))
  #:react (lambda (n msg)
            (set! (tick-only-count n) (+ 1 (tick-only-count n)))
            #f))

;; ── react sees msgs in order ────────────────────────────────────────

(let ((t (make-tape)))
  ((stateful-react-proc t) t 'a)
  ((stateful-react-proc t) t 'b)
  ((stateful-react-proc t) t 'c)
  (test-equal "react receives msgs in order"
    '(a b c)
    (reverse (tape-seen t))))

;; ── init msg, cmd return ────────────────────────────────────────────

(let ((n (make-ticker-installer)))
  (let ((cmd ((stateful-react-proc n) n (init))))
    (test-equal "init returns cmd"        'pretend-cmd cmd)
    (test-assert "init mutated state"      (ticker-installer-installed? n))))

;; ── subscribes filter ───────────────────────────────────────────────

(let ((n (make-tick-only)))
  (test-assert "subscribes list set"
    (let ((subs (stateful-subscribes n)))
      (and (list? subs) (member tick? subs))))
  ;; react would be filtered by engine cascade — we simulate by checking
  ;; the predicate ourselves.
  (let ((subs (stateful-subscribes n)))
    (test-assert "tick? matches a <tick>"
      (any (lambda (p) (p (tick))) subs))
    (test-assert "tick? does NOT match a key"
      (not (any (lambda (p) (p (key #\a))) subs)))))

;; ── subscribes=#f means receive-all ─────────────────────────────────

(let ((t (make-tape)))
  (test-equal "default subscribes is #f"
    #f (stateful-subscribes t)))

;; ── multi-state node + generalized set! ─────────────────────────────

(define-node point
  #:state ((x 0) (y 0))
  #:view  (lambda (p) (txt (string-append (number->string (point-x p)) ","
                                          (number->string (point-y p))))))

(let ((p (make-point #:x 3 #:y 4)))
  (test-equal "x slot" 3 (point-x p))
  (test-equal "y slot" 4 (point-y p))
  (set! (point-x p) 10)
  (test-equal "set! (point-x p) writes" 10 (point-x p)))

;; ── composition: nested nodes render correctly ──────────────────────

(let* ((tree (vbox (txt "header") (make-tape) (txt "footer")))
       (cmds (render tree 20 3))
       (texts (filter-map (lambda (c) (and (text-cmd? c) (text-str c))) cmds)))
  (test-equal "vbox with stateful renders all"
    '("header" "tape" "footer")
    texts))

(test-end "engine")
