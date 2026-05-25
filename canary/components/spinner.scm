(define-module (canary components spinner)
  #:use-module (canary node)
  #:use-module (canary layout)
  #:use-module (canary protocol)
  #:export (<spinner-state>
            spinner?
            make-spinner
            spinner-tick!
            spinner-frame-idx
            spinner-face
            spinner-dots
            spinner-line
            spinner-circle
            spinner-moon
            spinner-arrow))

;; A spinner is an exemplar for the cmd flow: on <init> it returns
;; (every #:hz 10 …) so the engine spawns a ticker fiber on its
;; behalf. Each <tick> advances frame-idx. View renders the current
;; frame. No user wiring required — drop one into a vbox and it spins.

(define spinner-dots   '("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"))
(define spinner-line   '("-" "\\" "|" "/"))
(define spinner-circle '("◐" "◓" "◑" "◒"))
(define spinner-moon   '("🌑" "🌒" "🌓" "🌔" "🌕" "🌖" "🌗" "🌘"))
(define spinner-arrow  '("←" "↖" "↑" "↗" "→" "↘" "↓" "↙"))

(define-node spinner
  #:state ((frames spinner-dots)
           (frame-idx 0)
           (face 'accent)
           (hz  10))
  #:subscribes (init? tick?)
  #:view  (lambda (s)
            (let ((fr (spinner-frames s)))
              (txt (list-ref fr (modulo (spinner-frame-idx s) (length fr)))
                   #:fg (spinner-face s))))
  #:react (lambda (s msg)
            (cond
             ((init? msg)
              ;; on first dispatch, install a ticker; engine runs the cmd.
              (every #:hz (spinner-hz s) (lambda () (tick))))
             ((tick? msg)
              (set! (spinner-frame-idx s) (+ 1 (spinner-frame-idx s)))
              #f))))

(define (spinner-tick! s)
  (set! (spinner-frame-idx s) (+ 1 (spinner-frame-idx s)))
  s)
