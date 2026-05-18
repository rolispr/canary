# 01 — Inherit from quill

## Goal

Adopt four architectural patterns from `quill` into `guile-canary` as one
coherent rewrite, not a sequence of optional refinements:

1. **Render command list** between component views and the terminal.
2. **Faces** (symbolic style names) replacing inline hex/ANSI in views.
3. **Backend layer** that maps faces + commands → ANSI bytes.
4. **Chord-based keymap** with multi-key sequences and `pending` state.

Each of these is wired through the existing TEA loop in `canary/app.scm`. No
parallel "v2" modules; the old string-returning `view` contract is replaced.

The fiber loop, `<app>` driver, `<component>` GOOPS class, and message
classes (`<key-msg>` etc.) stay — those are canary's identity, and quill
doesn't improve on them.

## What we do NOT inherit

- Structural sexp editing (`buffer/sexp.scm`) — canary isn't an editor.
- Tree-sitter (`ts/`) — overkill for a generic TUI lib.
- Project-type detection (`project/`) — host concern, not lib concern.
- REPL diagnostic parsing — Guile-REPL-specific.
- LLM modules — orthogonal.
- Quill's `event-kind` tagged-list event encoding — canary uses GOOPS message
  classes and stays on them. Only the chord/keymap layer is ported; the layer
  *above* it (mapping `<key-msg>` → chord) is new canary code.

## Architectural cut

### Current (string-returning view)

```
update → new-model → view(model) → STRING → terminal.scm display
```

`view` calls `vbox/boxed/txt/fg` which produce ANSI-embedded strings. There is
no intermediate representation. The dirty flag triggers a full screen redraw
of `csi[H + csi[2J + content`.

### Target (command-list view)

```
update → new-model → view(model) → cmd-list → backend → ANSI → terminal
                                       │
                                       └─ also: testable, diffable, cacheable
```

`view` returns a list of draw commands:

```scheme
'((clear)
  (rect 0 0 80 1 status-bar)
  (text 1 0 "canary" status-bar)
  (text 0 2 "Counter: 5" default)
  (cursor 11 2 block))
```

Backend converts these to ANSI. The shape of each command is fixed; new
command kinds require a backend update.

## Module changes

### New modules

| Module                  | Role                                                         |
| ----------------------- | ------------------------------------------------------------ |
| `canary/faces.scm`     | Default face table: `default`, `accent`, `dim`, `error`, …   |
| `canary/draw.scm`      | Command constructors + predicates (SRFI-9 records or lists). |
| `canary/backend.scm`   | Generic protocol: `backend-draw`, `backend-init`, …          |
| `canary/backend-ansi.scm` | ANSI implementation; owns face→SGR mapping.               |
| `canary/chord.scm`     | Ported from `quill/ui/keymap.scm` chord half.                |
| `canary/keymap.scm`    | Ported from `quill/ui/keymap.scm` keymap half.               |
| `canary/keymap-input.scm` | Maps `<key-msg>` → chord; runs `keymap-step` on app state. |

### Rewritten modules

| Module                       | Change                                                |
| ---------------------------- | ----------------------------------------------------- |
| `canary/style.scm`          | `fg/bg/bold` no longer emit ANSI strings; return face records. Inline-hex API is deleted. |
| `canary/layout.scm`         | `vbox/hbox/spacer` return command-list builders, not strings. |
| `canary/borders.scm`        | `boxed` emits `rect` + `text` commands, not strings.  |
| `canary/text.scm`           | `txt` emits `text` commands.                          |
| `canary/table.scm`          | Outputs commands.                                     |
| `canary/markdown.scm`       | Outputs commands.                                     |
| `canary/components/*.scm`   | All `*-render` / `*-view` return command lists.       |
| `canary/app.scm`            | `render-view` runs `view`, gets cmds, hands to backend. Initial chord input wiring lives here. |
| `canary/protocol.scm`       | `<key-msg>` gains `keysym` + `mods` slot semantics matching chord (current `key/alt/ctrl` collapses to these). Hard rename. |
| `canary/input.scm`          | Continues to produce `<key-msg>`. `parse-csi-sequence` etc. unchanged. Output format tightened to (keysym, mods-list). |

### Deleted

| Path                        | Why                                                   |
| --------------------------- | ----------------------------------------------------- |
| Inline-hex `fg`/`bg` API    | Replaced by faces. No back-compat alias.              |
| Direct ANSI in `style.scm`  | All ANSI lives in `backend-ansi.scm`.                 |
| String-concat view path     | One path: command list.                               |

## Concrete API targets

### `canary/draw.scm`

```scheme
(define-record-type <text-cmd>  (make-text col row str face)  text-cmd?  …)
(define-record-type <rect-cmd>  (make-rect col row w h face)  rect-cmd?  …)
(define-record-type <cursor-cmd>(make-cursor col row style)   cursor-cmd?…)
(define-record-type <clear-cmd> (make-clear)                  clear-cmd?)
```

(Records, not lists — typed dispatch in the backend, and `equal?` works on
them for tests. Quill uses lists; we upgrade because we don't share its
serialization needs.)

### `canary/faces.scm`

```scheme
(define-record-type <face>
  (make-face fg bg attrs)
  face?
  (fg face-fg) (bg face-bg) (attrs face-attrs))

(define +faces+
  `((default . ,(make-face #f #f '()))
    (accent  . ,(make-face "#ff6b9d" #f '(bold)))
    (dim     . ,(make-face "#666666" #f '()))
    (error   . ,(make-face "#ff5555" #f '(bold)))
    …))
```

Face *names* (symbols) appear in commands. The backend resolves the symbol to
RGB+attrs. Apps override by passing a face table to `make-app`.

### `canary/backend.scm`

```scheme
(define-generic backend-init)
(define-generic backend-shutdown)
(define-generic backend-draw)      ; (backend cmd-list)
(define-generic backend-size)      ; (backend) → (cols . rows)
```

`backend-ansi.scm` provides the concrete `<ansi-backend>` for terminals.
A future `<test-backend>` (collects commands in a vector for assertions)
costs no extra effort.

### `canary/chord.scm` + `canary/keymap.scm`

Direct port of quill's modules with one change: `chord` accepts `<key-msg>`
directly via a helper, since canary emits GOOPS messages, not tagged lists.

```scheme
(define (key-msg->chord km)
  (let ((mods '()))
    (when (alt km)  (set! mods (cons 'meta mods)))
    (when (ctrl km) (set! mods (cons 'control mods)))
    (apply chord (key km) mods)))
```

The keymap state machine is identical: `keymap-step km c` returns
`(values command-symbol-or-pending-or-#f new-km)`.

### `canary/keymap-input.scm`

Bridges `<key-msg>` flow into command dispatch. Holds the per-app keymap
state in the `<app>` (new slot `keymap`, default `(make-keymap '())`). When
event loop receives a key-msg, it first runs keymap-step; if a command
symbol comes out, it's dispatched as a message (`<command-msg>`) into the
user's `update`. If `'pending`, the message is swallowed and the keymap
state is updated. If `#f`, the key falls through to `update` as today.

This means examples shift from char-cond to keymap-driven update:

```scheme
;; before
(cond ((and (is-a? msg <key-msg>) (char=? (key msg) #\q)) (values m (quit-cmd))))

;; after
(define app-keymap
  (make-keymap
   `(((,(chord #\q))                . :quit)
     ((,(chord #\c 'control) ,(chord #\c 'control)) . :force-quit))))

(define (update m msg)
  (cond
   ((and (is-a? msg <command-msg>) (eq? (command msg) ':quit))
    (values m (quit-cmd)))))
```

## Acceptance criteria

The cut is done when:

- `examples/minimal-counter.scm` and `examples/four-panel-tui.scm` run and
  render correctly via the new pipeline.
- No `view` function in canary or examples returns a string.
- No module outside `canary/backend-ansi.scm` references `csi`, `\x1b`, or
  hex colors. (Grep gate in `make lint`.)
- `tests/test-draw.scm`, `tests/test-faces.scm`, `tests/test-chord.scm`,
  `tests/test-keymap.scm`, `tests/test-backend-ansi.scm` exist and pass.
- A `<test-backend>` exists and is used by at least one component test
  (e.g. `progress-render` produces a known cmd list).
- `examples/minimal-counter.scm` uses a keymap, not char-cond, for quit.

## Order of work (single PR, single commit, no shim phase)

1. Add `canary/draw.scm`, `canary/faces.scm`, `canary/backend.scm`,
   `canary/backend-ansi.scm` with full implementations + tests.
2. Rewrite `canary/style.scm`, `text.scm`, `borders.scm`, `layout.scm`,
   `table.scm`, `markdown.scm`, `canary/components/*` to emit commands.
3. Add `canary/chord.scm`, `canary/keymap.scm`, `canary/keymap-input.scm`
   with full tests.
4. Rewrite `canary/app.scm`: render path uses backend; input path runs the
   keymap before falling through to `update`. Add `<command-msg>` to
   `protocol.scm`.
5. Rewrite all `examples/*.scm` so none reference the old API. Examples
   that haven't been touched in a year and don't compile under the new API
   are deleted, not patched.
6. Add `Makefile` with `compile / test / lint / clean / repl` targets
   (mirror quill's, no Guix dep at this stage). The repl target runs
   `guile -L . --listen=37147` for live work.

## Risks and mitigations

- **Risk:** components currently mutate via GOOPS slots and assume
  re-render reads slots. Command-list output is fine with that.
- **Risk:** dirty-flag logic in `app.scm` assumes the whole screen is
  redrawn. Backend can do that in v1 (emit cmds → full ANSI buffer →
  one write). Diffing is a later optimization, not blocking.
- **Risk:** `<key-msg>` shape change breaks every example at once.
  Acceptable — that's the cut. All examples get rewritten in step 5.
- **Risk:** users of canary outside this repo. None exist; this is the
  user's own library.

## Out of scope

- Diff-based render (only redraw changed cells). Add later.
- Animation primitives beyond what `spring.scm` already provides.
- Mouse-event chord encoding. Mouse stays as `<mouse-msg>` direct to
  `update`; the keymap is keyboard-only.
- A palette/command-bar component. Apps build their own with the keymap
  primitives.
