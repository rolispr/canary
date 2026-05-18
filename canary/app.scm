(define-module (canary app)
  #:use-module (canary terminal)
  #:use-module (canary protocol)
  #:use-module (canary input)
  #:use-module (canary component)
  #:use-module (canary backend)
  #:use-module (canary backend-ansi)
  #:use-module (canary render)
  #:use-module (canary keymap)
  #:use-module (canary keymap-input)
  #:use-module ((canary draw) #:select (make-clear))
  #:use-module (fibers)
  #:use-module (fibers channels)
  #:use-module ((fibers timers) #:select ((sleep . fiber-sleep)))
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (system foreign)
  #:use-module (rnrs bytevectors)
  #:export (<app>
            make-app
            run-app
            send-message
            log-error
            get-errors
            app-model
            app-user-module
            app-keymap
            app-backend
            app-running?
            app-dirty?
            set-app-keymap!))

(define-class <app> ()
  (model #:init-keyword #:model #:accessor app-model)
  (user-module #:init-keyword #:user-module #:accessor app-user-module)
  (msg-ch #:init-keyword #:msg-ch #:accessor app-msg-ch)
  (backend #:init-keyword #:backend #:accessor app-backend)
  (keymap #:init-keyword #:keymap #:accessor app-keymap)
  (running? #:init-keyword #:running? #:init-value #t #:accessor app-running?)
  (errors #:init-keyword #:errors #:init-value '() #:accessor app-errors)
  (max-errors #:init-keyword #:max-errors #:init-value 10 #:accessor app-max-errors)
  (dirty? #:init-keyword #:dirty? #:init-value #t #:accessor app-dirty?))

(define* (make-app model user-module
                   #:key
                   (backend (make-ansi-backend))
                   (keymap (make-keymap '())))
  (make <app>
    #:model model
    #:user-module user-module
    #:msg-ch (make-channel)
    #:backend backend
    #:keymap keymap
    #:running? #t))

(define (send-message app msg)
  (when (app-running? app)
    (put-message (app-msg-ch app) msg)))

(define (set-app-keymap! app km)
  (set! (app-keymap app) km))

(define (log-error app msg)
  (let ((errs (app-errors app)))
    (set! (app-errors app)
          (take (cons msg errs)
                (min (app-max-errors app) (+ 1 (length errs)))))))

(define (get-errors app)
  (app-errors app))

(define (render-frame app)
  (catch #t
    (lambda ()
      (let* ((view-fn (module-ref (app-user-module app) 'view))
             (node (view-fn (app-model app)))
             (size (backend-size (app-backend app)))
             (cols (car size))
             (rows (cdr size))
             (cmds (cons (make-clear) (render node cols rows))))
        (backend-draw (app-backend app) cmds)))
    (lambda (key . args)
      (log-error app (format #f "render: ~a ~a" key args)))))

(define (run-command app cmd)
  (cond
   ((not cmd) #f)
   ((and (pair? cmd) (eq? (car cmd) 'batch))
    (for-each (lambda (c) (run-command app c)) (cdr cmd)))
   ((and (pair? cmd) (eq? (car cmd) 'sequence))
    (spawn-fiber
     (lambda ()
       (catch #t
         (lambda ()
           (for-each (lambda (c)
                       (when (and c (app-running? app))
                         (let ((msg (c)))
                           (when msg (send-message app msg)))))
                     (cdr cmd)))
         (lambda (key . args)
           (log-error app (format #f "~a: ~a" key args)))))))
   ((procedure? cmd)
    (spawn-fiber
     (lambda ()
       (catch #t
         (lambda ()
           (let ((msg (cmd)))
             (when msg (send-message app msg))))
         (lambda (key . args)
           (log-error app (format #f "~a: ~a" key args)))))))))

(define (input-loop app)
  (let loop ((last-mouse-time 0))
    (when (app-running? app)
      (let ((msg (read-key-msg))
            (now (get-internal-real-time)))
        (cond
         ((and msg (not (is-a? msg <mouse-msg>)))
          (send-message app msg)
          (fiber-sleep 0.01)
          (loop last-mouse-time))
         ((and msg (is-a? msg <mouse-msg>))
          (let ((elapsed-ms (quotient (* (- now last-mouse-time) 1000)
                                      internal-time-units-per-second)))
            (if (or (= last-mouse-time 0) (> elapsed-ms 16))
                (begin
                  (send-message app msg)
                  (fiber-sleep 0.01)
                  (loop now))
                (begin
                  (fiber-sleep 0.01)
                  (loop last-mouse-time)))))
         (else
          (fiber-sleep 0.01)
          (loop last-mouse-time)))))))

(define (render-loop app)
  (let loop ()
    (when (app-running? app)
      (when (app-dirty? app)
        (render-frame app)
        (set! (app-dirty? app) #f))
      (fiber-sleep 1/30)
      (loop))))

(define (dispatch-to-user app msg update-fn)
  (receive (delegated-model handled?)
      (auto-delegate-to-components (app-model app) msg)
    (set! (app-model app) delegated-model)
    (cond
     (handled? (set! (app-dirty? app) #t))
     (else
      (call-with-values
          (lambda () (update-fn (app-model app) msg))
        (lambda (new-model cmd)
          (set! (app-model app) new-model)
          (set! (app-dirty? app) #t)
          (when cmd (run-command app cmd))))))))

(define (event-loop app)
  (let loop ()
    (when (app-running? app)
      (let ((msg (get-message (app-msg-ch app)))
            (update-fn (module-ref (app-user-module app) 'update)))
        (cond
         ((is-a? msg <quit-msg>)
          (set! (app-running? app) #f))
         ((is-a? msg <key-msg>)
          (receive (result new-km) (feed-key-msg (app-keymap app) msg)
            (set-app-keymap! app new-km)
            (cond
             ((eq? result 'pending) #f)
             (result
              (dispatch-to-user app (make <command-msg> #:command result) update-fn))
             (else
              (dispatch-to-user app msg update-fn))))
          (loop))
         (else
          (dispatch-to-user app msg update-fn)
          (loop)))))))

(define %dup2
  (pointer->procedure int
                      (dynamic-func "dup2" (dynamic-link))
                      (list int int)))

(define (run-app app)
  (let ((cleanup-done #f)
        (stderr-pipe (pipe))
        (saved-stderr-fd #f))
    (define (do-cleanup)
      (unless cleanup-done
        (set! cleanup-done #t)
        (backend-shutdown (app-backend app))
        (when saved-stderr-fd
          (%dup2 saved-stderr-fd 2))))

    (catch #t
      (lambda ()
        (dynamic-wind
          (lambda ()
            (set! saved-stderr-fd (%dup2 2 100))
            (%dup2 (port->fdes (cdr stderr-pipe)) 2)
            (backend-init (app-backend app))
            (setup-signal-handlers do-cleanup))

          (lambda ()
            (run-fibers
             (lambda ()
               (spawn-fiber (lambda () (event-loop app)))
               (spawn-fiber (lambda () (input-loop app)))
               (spawn-fiber (lambda () (render-loop app)))
               (let* ((init-fn (module-ref (app-user-module app) 'init))
                      (init-cmd (init-fn (app-model app))))
                 (when init-cmd (run-command app init-cmd)))
               (let ((size (backend-size (app-backend app))))
                 (send-message app (make <window-size-msg>
                                     #:width (car size)
                                     #:height (cdr size))))
               (spawn-fiber
                (lambda ()
                  (let loop ()
                    (when (app-running? app)
                      (when (char-ready? (car stderr-pipe))
                        (let ((line (catch #t
                                      (lambda () (read-line (car stderr-pipe)))
                                      (lambda _ #f))))
                          (when (and line (not (eof-object? line)))
                            (log-error app line))))
                      (fiber-sleep 1/20)
                      (loop)))))
               (let loop ()
                 (when (app-running? app)
                   (fiber-sleep 1/10)
                   (loop))))
             #:hz 100))

          (lambda ()
            (do-cleanup))))

      (lambda (key . args)
        (do-cleanup)
        (apply throw key args)))))
