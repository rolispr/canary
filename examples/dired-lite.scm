;;; dired-lite.scm — a tiny file browser as one shareable node.
;;;
;;; Run: guile -L /path/to/guile-canary examples/dired-lite.scm
;;;
;;; Keys: j/k or ↑/↓ → move cursor; enter → cd into dir / display file;
;;;       u → up one directory; q → quit.
;;;
;;; What this shows:
;;;   - init returns a cmd: a thunk that scandirs the start path and
;;;     sends back the entries as a msg. State is updated when that
;;;     msg arrives. No blocking IO in init itself.
;;;   - composition: a top-level vbox wraps the dired node next to a
;;;     status panel. The cascade reaches both stateful nodes; each
;;;     ignores msgs it doesn't care about via its react cond.
;;;   - publishable shape: someone else can `(use-modules (this))` and
;;;     drop `(make-dired #:path "/foo")` into their own tree.

(use-modules (canary)
             (canary components panel)
             (ice-9 ftw))

(define (read-dir path)
  ;; Sorted entries; ".." first if not at root.
  (let ((kids (scandir path
                       (lambda (n) (not (or (string=? n ".")
                                            (string=? n "..")))))))
    (cons ".." (or kids '()))))

(define-node dired
  #:state ((path    "/")
           (entries '())
           (cursor  0)
           (status  ""))
  #:subscribes (init? key?)
  #:view
  (lambda (d)
    (let* ((es  (dired-entries d))
           (cur (dired-cursor d)))
      (vbox
       (txt (dired-path d) #:fg 'heading #:bold)
       (spacer 1)
       (cond
        ((null? es)
         (txt "(loading…)" #:fg 'muted #:italic))
        (else
         (apply vbox
                (map (lambda (e i)
                       (let ((sel? (= i cur)))
                         (hbox (txt (if sel? " ▶ " "   ")
                                    #:fg (if sel? 'accent 'muted))
                               (txt e
                                    #:fg (if sel? 'accent 'fg)
                                    #:bold sel?))))
                     es
                     (iota (length es))))))
       (spacer 1)
       (txt (dired-status d) #:fg 'muted #:italic))))
  #:react
  (lambda (d msg)
    (cond
     ((init? msg)
      ;; The cmd: a thunk that does the scandir, returns a msg the
      ;; engine will dispatch back to react.
      (lambda ()
        `(dired-loaded ,(read-dir (dired-path d)))))
     ((key? msg)
      (let ((k (key-sym msg))
            (es (dired-entries d))
            (cur (dired-cursor d)))
        (cond
         ((or (eqv? k #\j) (eq? k 'down))
          (set! (dired-cursor d)
                (min (- (length es) 1) (+ 1 cur))) #f)
         ((or (eqv? k #\k) (eq? k 'up))
          (set! (dired-cursor d) (max 0 (- cur 1))) #f)
         ((eq? k 'return)
          (let ((entry (and (not (null? es)) (list-ref es cur))))
            (cond
             ((not entry) #f)
             ((string=? entry "..")
              (cd! d (dirname (dired-path d))))
             (else
              (let ((full (string-append (dired-path d) "/" entry)))
                (if (file-is-directory? full)
                    (cd! d full)
                    (begin
                      (set! (dired-status d)
                            (string-append "file: " full))
                      #f)))))))
         (else #f))))
     ((and (pair? msg) (eq? (car msg) 'dired-loaded))
      (set! (dired-entries d) (cadr msg))
      (set! (dired-cursor d) 0)
      #f)
     (else #f))))

(define (cd! d new-path)
  (set! (dired-path d) new-path)
  (set! (dired-status d) "")
  ;; trigger a reload by returning the same init-style cmd
  (lambda () `(dired-loaded ,(read-dir new-path))))

(define (file-is-directory? p)
  (catch #t
    (lambda () (eq? (stat:type (stat p)) 'directory))
    (lambda _ #f)))

(define (dirname p)
  (let ((slash (string-rindex p #\/)))
    (cond
     ((not slash) "/")
     ((zero? slash) "/")
     (else (substring p 0 slash)))))

(define hint
  (make-panel #:title "keys"
              #:face  'muted
              #:content
              (vbox (txt "j / ↓   down")
                    (txt "k / ↑   up")
                    (txt "↵       enter / open")
                    (txt "u       parent")
                    (txt "q       quit"))))

(define app
  (hbox (make-dired #:path (or (getenv "HOME") "/"))
        (spacer #:w 2)
        hint))

(run-app app
         #:title  "dired-lite"
         #:keymap (keymap (bind #\q 'quit) (bind 'escape 'quit))
         #:mouse  'off)
