;;; components/textarea.scm --- Multi-line text editor

(define-module (canary components textarea)
  #:use-module (canary protocol)
  #:use-module (canary component)
  #:use-module (canary style)
  #:use-module (canary text)
  #:use-module (canary zones)
  #:use-module (ice-9 match)
  #:use-module (ice-9 format)
  #:use-module (ice-9 receive)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:export (make-textarea
            textarea-value
            textarea-set-value!
            textarea-update
            textarea-view
            <textarea>))

;;; Textarea class
(define-class <textarea> (<component>)
  (width #:init-keyword #:width #:init-value 40 #:accessor textarea-width)
  (height #:init-keyword #:height #:init-value 6 #:accessor textarea-height)
  (lines #:accessor textarea-lines)
  (row #:init-value 0 #:accessor textarea-row)
  (col #:init-value 0 #:accessor textarea-col)
  (placeholder #:init-keyword #:placeholder #:init-value "" #:accessor textarea-placeholder)
  (show-line-numbers #:init-keyword #:show-line-numbers #:init-value #t #:accessor textarea-show-line-numbers)
  (prompt #:init-keyword #:prompt #:init-value "> " #:accessor textarea-prompt)
  (char-limit #:init-keyword #:char-limit #:init-value 0 #:accessor textarea-char-limit)
  (max-lines #:init-keyword #:max-lines #:init-value 1000 #:accessor textarea-max-lines)
  (zone-id #:init-keyword #:zone-id #:init-value #f #:accessor textarea-zone-id))

(define* (make-textarea #:key (width 40) (height 6) (placeholder "") (zone-id #f))
  "Create a new textarea"
  (let ((ta (make <textarea> #:width width #:height height #:placeholder placeholder #:zone-id zone-id)))
    (set! (textarea-lines ta) (vector ""))
    ta))

;;; Content management
(define (textarea-set-value! textarea text)
  "Set textarea content"
  (set! (textarea-lines textarea)
        (list->vector (string-split text #\newline)))
  (set! (textarea-row textarea) 0)
  (set! (textarea-col textarea) 0)
  textarea)

(define (textarea-value textarea)
  "Get textarea content as string"
  (let ((lines (textarea-lines textarea)))
    (if (zero? (vector-length lines))
        ""
        (string-join (vector->list lines) nl))))

(define (textarea-current-line textarea)
  "Get current line text"
  (vector-ref (textarea-lines textarea) (textarea-row textarea)))

(define (textarea-set-cursor! textarea col)
  "Set cursor column, clamping to line length"
  (let* ((lines (textarea-lines textarea))
         (row (textarea-row textarea))
         (line (vector-ref lines row)))
    (set! (textarea-col textarea)
          (max 0 (min col (string-length line))))))

(define (textarea-insert-string! textarea str)
  "Insert string at cursor"
  (let* ((lines (textarea-lines textarea))
         (row (textarea-row textarea))
         (col (textarea-col textarea))
         (current-line (vector-ref lines row))
         (new-lines (string-split str #\newline)))

    (if (= (length new-lines) 1)
        ;; Single line insert
        (let ((new-line (string-append (substring current-line 0 col)
                                      (car new-lines)
                                      (substring current-line col))))
          (vector-set! lines row new-line)
          (set! (textarea-col textarea)
                (+ col (string-length (car new-lines)))))

        ;; Multi-line insert
        (let* ((first-part (string-append (substring current-line 0 col)
                                         (car new-lines)))
               (last-part (string-append (last new-lines)
                                        (substring current-line col)))
               (middle-parts (drop-right (cdr new-lines) 1))
               (total-new-lines (- (length new-lines) 1))
               (new-vector (make-vector (+ (vector-length lines) total-new-lines))))

          ;; Copy lines before insertion
          (let loop ((i 0))
            (when (< i row)
              (vector-set! new-vector i (vector-ref lines i))
              (loop (1+ i))))

          ;; Set first line
          (vector-set! new-vector row first-part)

          ;; Add middle lines
          (let loop ((parts middle-parts) (i (1+ row)))
            (when (not (null? parts))
              (vector-set! new-vector i (car parts))
              (loop (cdr parts) (1+ i))))

          ;; Set last line
          (vector-set! new-vector (+ row total-new-lines) last-part)

          ;; Copy remaining lines
          (let loop ((i (1+ row)))
            (when (< i (vector-length lines))
              (vector-set! new-vector (+ i total-new-lines)
                          (vector-ref lines i))
              (loop (1+ i))))

          (set! (textarea-lines textarea) new-vector)
          (set! (textarea-row textarea) (+ row total-new-lines))
          (set! (textarea-col textarea) (string-length (last new-lines))))))
  textarea)

(define (textarea-newline! textarea)
  "Insert newline at cursor"
  (let* ((lines (textarea-lines textarea))
         (row (textarea-row textarea))
         (col (textarea-col textarea))
         (line (vector-ref lines row))
         (before (substring line 0 col))
         (after (substring line col))
         (new-lines (make-vector (1+ (vector-length lines)))))

    ;; Copy lines before split
    (let loop ((i 0))
      (when (< i row)
        (vector-set! new-lines i (vector-ref lines i))
        (loop (1+ i))))

    ;; Add split lines
    (vector-set! new-lines row before)
    (vector-set! new-lines (1+ row) after)

    ;; Copy lines after split
    (let loop ((i (1+ row)))
      (when (< i (vector-length lines))
        (vector-set! new-lines (1+ i) (vector-ref lines i))
        (loop (1+ i))))

    (set! (textarea-lines textarea) new-lines)
    (set! (textarea-row textarea) (1+ row))
    (set! (textarea-col textarea) 0))
  textarea)

(define (textarea-delete-char-backward! textarea)
  "Delete character before cursor (backspace)"
  (let ((lines (textarea-lines textarea))
        (row (textarea-row textarea))
        (col (textarea-col textarea)))
    (cond
     ;; At start of line - merge with previous
     ((and (zero? col) (> row 0))
      (let* ((prev-line (vector-ref lines (1- row)))
             (curr-line (vector-ref lines row))
             (merged (string-append prev-line curr-line))
             (new-col (string-length prev-line))
             (new-lines (make-vector (1- (vector-length lines)))))
        ;; Set merged line
        (vector-set! lines (1- row) merged)
        ;; Copy to new vector, skipping current row
        (let loop ((i 0) (j 0))
          (when (< j (vector-length new-lines))
            (if (= i row)
                (loop (1+ i) j)
                (begin
                  (vector-set! new-lines j (vector-ref lines i))
                  (loop (1+ i) (1+ j))))))
        (set! (textarea-lines textarea) new-lines)
        (set! (textarea-row textarea) (1- row))
        (set! (textarea-col textarea) new-col)))

     ;; In middle of line
     ((> col 0)
      (let* ((line (vector-ref lines row))
             (new-line (string-append (substring line 0 (1- col))
                                     (substring line col))))
        (vector-set! lines row new-line)
        (set! (textarea-col textarea) (1- col))))))
  textarea)

(define (textarea-delete-char-forward! textarea)
  "Delete character at cursor (delete)"
  (let ((lines (textarea-lines textarea))
        (row (textarea-row textarea))
        (col (textarea-col textarea)))
    (cond
     ;; At end of line - merge with next
     ((and (= col (string-length (vector-ref lines row)))
           (< row (1- (vector-length lines))))
      (let* ((curr-line (vector-ref lines row))
             (next-line (vector-ref lines (1+ row)))
             (merged (string-append curr-line next-line))
             (new-lines (make-vector (1- (vector-length lines)))))
        (vector-set! lines row merged)
        ;; Copy to new vector, skipping next row
        (let loop ((i 0) (j 0))
          (when (< j (vector-length new-lines))
            (if (= i (1+ row))
                (loop (1+ i) j)
                (begin
                  (vector-set! new-lines j (vector-ref lines i))
                  (loop (1+ i) (1+ j))))))
        (set! (textarea-lines textarea) new-lines)))

     ;; In middle of line
     ((< col (string-length (vector-ref lines row)))
      (let* ((line (vector-ref lines row))
             (new-line (string-append (substring line 0 col)
                                     (substring line (1+ col)))))
        (vector-set! lines row new-line)))))
  textarea)

;;; Update
(define (textarea-update textarea msg)
  "Update textarea with message"
  (cond
   ;; Mouse click - position cursor
   ((and (is-a? msg <mouse-msg>) (eq? (action msg) 'press))
    (let* ((zone-id (textarea-zone-id textarea))
           (zone (and zone-id (zone-get zone-id))))
      (if zone
          ;; Use zone to get relative coordinates
          (receive (zone-start-x zone-start-y zone-end-x zone-end-y)
              (zone-coords zone)
            (let* ((prompt-len (visible-length (textarea-prompt textarea)))
                   (click-x (x msg))
                   (click-y (y msg))
                   (rel-y (- click-y zone-start-y))
                   (lines (textarea-lines textarea))
                   (num-lines (vector-length lines))
                   (new-row (min (max 0 rel-y) (1- num-lines))))
              (when (< new-row num-lines)
                (let* ((line-offset (if (= new-row 0) zone-start-x 0))
                       (rel-x (max 0 (- click-x line-offset prompt-len)))
                       (line (vector-ref lines new-row))
                       (new-col (min rel-x (string-length line))))
                  (set! (textarea-row textarea) new-row)
                  (set! (textarea-col textarea) new-col)))
              (values textarea #t)))
          ;; No zone - can't position cursor accurately
          (values textarea #f))))

   ;; Not focused - don't handle
   ((not (component-focused? textarea))
    (values textarea #f))

   ;; Key messages
   ((is-a? msg <key-msg>)
        (let ((k (key msg)))
          (match k
            ('up
             (when (> (textarea-row textarea) 0)
               (set! (textarea-row textarea) (1- (textarea-row textarea)))
               (textarea-set-cursor! textarea (textarea-col textarea)))
             (values textarea #t))

            ('down
             (when (< (textarea-row textarea) (1- (vector-length (textarea-lines textarea))))
               (set! (textarea-row textarea) (1+ (textarea-row textarea)))
               (textarea-set-cursor! textarea (textarea-col textarea)))
             (values textarea #t))

            ('left
             (if (> (textarea-col textarea) 0)
                 (set! (textarea-col textarea) (1- (textarea-col textarea)))
                 (when (> (textarea-row textarea) 0)
                   (set! (textarea-row textarea) (1- (textarea-row textarea)))
                   (textarea-set-cursor! textarea (string-length (textarea-current-line textarea)))))
             (values textarea #t))

            ('right
             (let ((line-len (string-length (textarea-current-line textarea))))
               (if (< (textarea-col textarea) line-len)
                   (set! (textarea-col textarea) (1+ (textarea-col textarea)))
                   (when (< (textarea-row textarea) (1- (vector-length (textarea-lines textarea))))
                     (set! (textarea-row textarea) (1+ (textarea-row textarea)))
                     (set! (textarea-col textarea) 0))))
             (values textarea #t))

            ('home
             (set! (textarea-col textarea) 0)
             (values textarea #t))

            ('end
             (textarea-set-cursor! textarea (string-length (textarea-current-line textarea)))
             (values textarea #t))

            ('backspace
             (textarea-delete-char-backward! textarea)
             (values textarea #t))

            ('delete
             (textarea-delete-char-forward! textarea)
             (values textarea #t))

            ('enter
             (textarea-newline! textarea)
             (values textarea #t))

            ('escape
             (component-blur! textarea)
             (values textarea #f))

            (_
             (if (char? k)
                 (begin
                   (textarea-insert-string! textarea (string k))
                   (values textarea #t))
                 (values textarea #f))))))

   (else (values textarea #f))))

;;; Component protocol
(define-method (component-update (textarea <textarea>) msg)
  "Handle messages via component protocol"
  (textarea-update textarea msg))

;;; View
(define (textarea-view textarea)
  "Render textarea"
  (let ((lines (textarea-lines textarea))
        (height (textarea-height textarea))
        (prompt (textarea-prompt textarea))
        (row (textarea-row textarea))
        (col (textarea-col textarea))
        (focused (component-focused? textarea))
        (placeholder (textarea-placeholder textarea))
        (zone-id (textarea-zone-id textarea)))

    (let ((content
           (if (and (= (vector-length lines) 1)
                    (string=? (vector-ref lines 0) "")
                    (not (string=? placeholder "")))
               ;; Empty with placeholder
               (string-append prompt placeholder)

               ;; Render visible lines
               (let ((result '()))
                 (do ((i 0 (1+ i)))
                     ((>= i height))
                   (let* ((line-text (if (< i (vector-length lines))
                                         (vector-ref lines i)
                                         ""))
                          (rendered-line
                           (if (and focused (= i row))
                               ;; Line with cursor
                               (let* ((len (string-length line-text))
                                      (safe-col (min col len)))
                                 (string-append
                                  (substring line-text 0 safe-col)
                                  (reverse-video (string (if (< safe-col len)
                                                             (string-ref line-text safe-col)
                                                             #\space)))
                                  (if (< safe-col len)
                                      (substring line-text (1+ safe-col))
                                      "")))
                               ;; Line without cursor
                               line-text)))
                     (set! result (cons (string-append prompt rendered-line) result))))
                 (string-join (reverse result) nl)))))
      ;; Wrap with zone marker if zone-id is set
      (if zone-id
          (zone-mark zone-id content)
          content))))
