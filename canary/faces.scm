(define-module (canary faces)
  #:use-module (srfi srfi-9)
  #:export (<face>
            face?
            make-face
            face-fg
            face-bg
            face-attrs
            default-faces
            face-table-lookup
            extend-face-table))

(define-record-type <face>
  (make-face fg bg attrs)
  face?
  (fg face-fg)
  (bg face-bg)
  (attrs face-attrs))

(define default-faces
  `((default  . ,(make-face #f #f '()))
    (accent   . ,(make-face "#ff6b9d" #f '(bold)))
    (dim      . ,(make-face "#666666" #f '()))
    (muted    . ,(make-face "#888888" #f '()))
    (error    . ,(make-face "#ff5555" #f '(bold)))
    (warning  . ,(make-face "#f4c061" #f '()))
    (info     . ,(make-face "#7cd1e3" #f '()))
    (success  . ,(make-face "#00ff87" #f '()))
    (heading  . ,(make-face "#5599ff" #f '(bold)))
    (link     . ,(make-face "#5599ff" #f '(underline)))
    (selection . ,(make-face "#ffffff" "#322a44" '()))
    (cursor   . ,(make-face "#000000" "#ffffff" '()))
    (placeholder . ,(make-face "#666666" #f '(italic)))))

(define (face-table-lookup table name)
  (cond
   ((face? name) name)
   ((not name) (face-table-lookup table 'default))
   ((assq name table) => cdr)
   (else (face-table-lookup table 'default))))

(define (extend-face-table base overrides)
  (append overrides base))
