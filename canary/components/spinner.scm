(define-module (canary components spinner)
  #:use-module (canary layout)
  #:use-module (srfi srfi-9)
  #:export (<spinner>
            spinner?
            make-spinner
            spinner-tick!
            spinner-view
            spinner-dots
            spinner-line
            spinner-circle
            spinner-moon
            spinner-arrow))

(define-record-type <spinner>
  (%make-spinner frames frame-idx face)
  spinner?
  (frames spinner-frames)
  (frame-idx spinner-frame-idx set-spinner-frame-idx!)
  (face spinner-face))

(define spinner-dots
  '("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"))

(define spinner-line
  '("-" "\\" "|" "/"))

(define spinner-circle
  '("◐" "◓" "◑" "◒"))

(define spinner-moon
  '("🌑" "🌒" "🌓" "🌔" "🌕" "🌖" "🌗" "🌘"))

(define spinner-arrow
  '("←" "↖" "↑" "↗" "→" "↘" "↓" "↙"))

(define* (make-spinner #:key (frames spinner-dots) (face 'accent))
  (%make-spinner (list->vector frames) 0 face))

(define (spinner-tick! s)
  (let* ((frames (spinner-frames s))
         (idx (spinner-frame-idx s))
         (next (modulo (1+ idx) (vector-length frames))))
    (set-spinner-frame-idx! s next)
    s))

(define (spinner-view s)
  (let ((frames (spinner-frames s))
        (idx (spinner-frame-idx s)))
    (txt (vector-ref frames idx) #:face (spinner-face s))))
