(define-module (canary key)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:export (<key> key key?
            key-sym key-mods
            key=? key->string
            normalize-key))

(define-class <key> ()
  (sym  #:init-keyword #:sym  #:accessor key-sym)
  (mods #:init-keyword #:mods #:accessor key-mods))

(define (canon-mod m)
  (case m
    ((control ctrl)        'control)
    ((alt meta option)     'alt)
    ((shift)               'shift)
    ((super cmd command)   'super)
    (else (error "key: unknown modifier" m))))

(define (canon-mods mods)
  (sort (delete-duplicates (map canon-mod mods))
        (lambda (a b) (string<? (symbol->string a) (symbol->string b)))))

(define (key? x) (is-a? x <key>))

(define (key sym . mods)
  (make <key> #:sym sym #:mods (canon-mods mods)))

(define (key=? a b)
  (and (key? a) (key? b)
       (equal? (key-sym a) (key-sym b))
       (equal? (key-mods a) (key-mods b))))

(define (key->string k)
  (let ((s (key-sym k)))
    (string-append
     (apply string-append
            (map (lambda (m)
                   (case m
                     ((control) "C-")
                     ((alt)     "A-")
                     ((shift)   "S-")
                     ((super)   "s-")
                     (else (string-append (symbol->string m) "-"))))
                 (key-mods k)))
     (cond
      ((char? s)   (string s))
      ((symbol? s) (symbol->string s))
      (else        (format #f "~a" s))))))

(define (normalize-key x)
  (cond
   ((key? x)    x)
   ((char? x)   (make <key> #:sym x #:mods '()))
   ((symbol? x) (make <key> #:sym x #:mods '()))
   ((and (pair? x) (eq? (car x) 'mouse))
    (make <key> #:sym (cons 'mouse (cadr x)) #:mods '()))
   ((and (pair? x) (eq? (car x) 'mouse-scroll))
    (make <key> #:sym (cons 'mouse-scroll (cadr x)) #:mods '()))
   ((and (pair? x) (or (char? (car x)) (symbol? (car x))))
    (make <key> #:sym (car x) #:mods (canon-mods (cdr x))))
   (else (error "not a key" x))))
