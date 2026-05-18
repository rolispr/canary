(add-to-load-path (string-append (dirname (current-filename)) "/.."))

(use-modules (srfi srfi-64)
             (srfi srfi-1)
             (canary view)
             (canary layout)
             (canary borders)
             (canary draw)
             (canary render))

(test-begin "render")

(let ((cmds (render (txt "hi") 80 24)))
  (test-equal "single text yields one text-cmd" 1 (length cmds))
  (test-assert "is a text-cmd" (text-cmd? (car cmds)))
  (test-equal "text-cmd has correct string" "hi" (text-str (car cmds)))
  (test-equal "text-cmd at origin" 0 (text-col (car cmds)))
  (test-equal "text-cmd row 0" 0 (text-row (car cmds))))

(let ((cmds (render (vbox (txt "a") (txt "b")) 80 24)))
  (test-equal "vbox yields 2 cmds" 2 (length cmds))
  (test-equal "first row 0" 0 (text-row (car cmds)))
  (test-equal "second row 1" 1 (text-row (cadr cmds))))

(let ((cmds (render (hbox (txt "ab") (txt "cd")) 80 24)))
  (test-equal "hbox yields 2 cmds" 2 (length cmds))
  (test-equal "first col 0" 0 (text-col (car cmds)))
  (test-equal "second col 2" 2 (text-col (cadr cmds))))

(let ((cmds (render (boxed (txt "x")) 80 24)))
  (test-assert "boxed yields multiple cmds" (> (length cmds) 1))
  (test-assert "all are text-cmds" (every text-cmd? cmds)))

(test-end "render")
