(add-to-load-path (string-append (dirname (current-filename)) "/.."))

(use-modules (srfi srfi-64)
             (canary chord))

(test-begin "chord")

(test-assert "char chord equal" (chord=? (chord #\a) (chord #\a)))
(test-assert "different chars not equal" (not (chord=? (chord #\a) (chord #\b))))
(test-assert "mods order ignored"
             (chord=? (chord #\a 'control 'meta)
                      (chord #\a 'meta 'control)))
(test-assert "duplicate mods deduped"
             (chord=? (chord #\a 'control)
                      (chord #\a 'control 'control)))
(test-equal "format with mods" "C-x" (chord->string (chord #\x 'control)))
(test-equal "format with multiple mods" "C-M-x" (chord->string (chord #\x 'meta 'control)))

(test-end "chord")
