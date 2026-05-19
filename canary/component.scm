(define-module (canary component)
  #:use-module (oop goops)
  #:export (<component>
            component-focused?
            component-focus!
            component-blur!
            react))

(define-class <component> ()
  (focused? #:init-value #f #:accessor component-focused?))

(define-generic react)

(define-method (react (c <component>) msg)
  c)

(define-method (component-focus! (c <component>))
  (set! (component-focused? c) #t)
  c)

(define-method (component-blur! (c <component>))
  (set! (component-focused? c) #f)
  c)
