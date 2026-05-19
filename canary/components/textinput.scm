(define-module (canary components textinput)
  #:use-module (canary view)
  #:use-module (canary layout)
  #:use-module (canary protocol)
  #:use-module (canary component)
  #:use-module (srfi srfi-9)
  #:use-module (ice-9 match)
  #:use-module (oop goops)
  #:export (<textinput>
            make-textinput
            textinput?
            textinput-value
            textinput-set-value!
            textinput-cursor
            textinput-view))

(define-class <textinput> (<component>)
  (value #:init-keyword #:value #:init-value "" #:accessor textinput-value)
  (cursor #:init-value 0 #:accessor textinput-cursor)
  (placeholder #:init-keyword #:placeholder #:init-value "" #:accessor textinput-placeholder)
  (prompt #:init-keyword #:prompt #:init-value "> " #:accessor textinput-prompt)
  (width #:init-keyword #:width #:init-value 20 #:accessor textinput-width)
  (char-limit #:init-keyword #:char-limit #:init-value 0 #:accessor textinput-char-limit))

(define* (make-textinput #:key (value "") (placeholder "") (prompt "> ")
                         (width 20) (char-limit 0))
  (make <textinput>
    #:value value
    #:placeholder placeholder
    #:prompt prompt
    #:width width
    #:char-limit char-limit))

(define (textinput-set-value! ti v)
  (set! (textinput-value ti) v)
  (set! (textinput-cursor ti) (string-length v))
  ti)

(define-method (react (ti <textinput>) msg)
  (cond
   ((and (mouse? msg) (eq? (mouse-action msg) 'press))
    (let* ((pl (string-length (textinput-prompt ti)))
           (rel (max 0 (- (mouse-x msg) pl)))
           (new-pos (min rel (string-length (textinput-value ti)))))
      (set! (textinput-cursor ti) new-pos)
      (values ti #t)))
   ((not (key? msg))
    (values ti #f))
   (else
    (let ((k (key-char msg))
          (val (textinput-value ti))
          (cur (textinput-cursor ti))
          (limit (textinput-char-limit ti)))
      (match k
        ('backspace
         (when (> cur 0)
           (set! (textinput-value ti)
                 (string-append (substring val 0 (- cur 1)) (substring val cur)))
           (set! (textinput-cursor ti) (- cur 1)))
         (values ti #t))
        ('delete
         (when (< cur (string-length val))
           (set! (textinput-value ti)
                 (string-append (substring val 0 cur) (substring val (+ cur 1)))))
         (values ti #t))
        ('left
         (when (> cur 0) (set! (textinput-cursor ti) (- cur 1)))
         (values ti #t))
        ('right
         (when (< cur (string-length val)) (set! (textinput-cursor ti) (+ cur 1)))
         (values ti #t))
        ('home (set! (textinput-cursor ti) 0) (values ti #t))
        ('end (set! (textinput-cursor ti) (string-length val)) (values ti #t))
        (_
         (cond
          ((and (char? k) (or (zero? limit) (< (string-length val) limit)))
           (set! (textinput-value ti)
                 (string-append (substring val 0 cur) (string k) (substring val cur)))
           (set! (textinput-cursor ti) (+ cur 1))
           (values ti #t))
          (else (values ti #f)))))))))

(define (textinput-view ti)
  (let* ((val (textinput-value ti))
         (prompt (textinput-prompt ti))
         (w (textinput-width ti))
         (cur (textinput-cursor ti))
         (focused? (component-focused? ti))
         (ph (textinput-placeholder ti))
         (showing-ph? (and (string-null? val) (not (string-null? ph)))))
    (cond
     (showing-ph?
      (hbox (txt prompt)
            (if focused? (txt " " #:reverse? #t) #f)
            (txt ph #:face 'placeholder)))
     (else
      (let* ((start (max 0 (- cur (- w 5))))
             (visible (if (> (string-length val) w)
                          (substring val start (min (string-length val) (+ start w)))
                          val))
             (cpos (- cur start)))
        (cond
         ((and focused? (>= cpos 0) (<= cpos (string-length visible)))
          (let ((left (substring visible 0 cpos))
                (cell (if (< cpos (string-length visible))
                          (string (string-ref visible cpos))
                          " "))
                (right (if (< cpos (string-length visible))
                           (substring visible (+ cpos 1))
                           "")))
            (hbox (txt prompt)
                  (txt left)
                  (txt cell #:reverse? #t)
                  (txt right))))
         (else
          (hbox (txt prompt) (txt visible)))))))))
