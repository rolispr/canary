# 01 — Inherit from quill (result)

## What landed

### New modules

- `canary/draw.scm` — `<text-cmd>`, `<fill-cmd>`, `<cursor-cmd>`, `<clear-cmd>` records.
- `canary/faces.scm` — `<face>` record, `default-faces` table, `face-table-lookup`.
- `canary/view.scm` — view-node records (`<text-node>`, `<vbox-node>`, `<hbox-node>`,
  `<boxed-node>`, `<spacer-node>`, `<fill-node>`, `<pad-node>`, `<align-node>`,
  `<width-node>`, `<height-node>`, `<cursor-node>`, `<overlay-node>`) plus
  `<rect>` and `view-size`.
- `canary/render.scm` — `render` / `view->cmds`: flattens a view-node tree
  to a list of draw commands given a target rect.
- `canary/backend.scm` — `<backend>` GOOPS class + generics
  `backend-init` / `backend-shutdown` / `backend-draw` / `backend-size`.
- `canary/backend-ansi.scm` — `<ansi-backend>` implementation; the ONLY
  place ANSI escape codes are emitted. `face->sgr` + `cmds->ansi`.
- `canary/chord.scm` — ported from quill: `<chord>`, `chord`, `chord=?`,
  `chord->string`.
- `canary/keymap.scm` — ported from quill: `<keymap>`, `keymap-step` with
  exact/`'pending`/`#f` semantics.
- `canary/keymap-input.scm` — `<key-msg>` → `<chord>` bridge; `feed-key-msg`
  runs `keymap-step` on the app keymap.

### Adjustment to the plan

The plan said `view` returns a flat command list. In practice that forced
the user to do coordinate math by hand. `view` now returns a **view-node
tree**, and `render` flattens it to commands. The user-facing API stays
composable (`vbox`/`hbox`/`boxed`/`txt` etc.). The backend still consumes
flat commands.

### Rewritten modules

- `canary/style.scm` — old `fg`/`bg`/`bold` string-wrappers deleted.
  Replaced by `with-face` / `with-attrs` / `bold` / `italic` / `underline`
  / `strikethrough` / `reverse-video` operating on view nodes.
- `canary/layout.scm` — `txt` / `vbox` / `hbox` / `spacer` / `pad` /
  `align` / `width` / `height` / `fill` / `place-cursor` all return view
  nodes.
- `canary/borders.scm` — `boxed` returns a `<boxed-node>`. Border records
  unchanged.
- `canary/text.scm` — collapsed to just `visible-length`. The old `nl`
  constant is gone.
- `canary/table.scm` — `table-view` returns a view node.
- `canary/tree.scm` — `tree-view` returns a view node.
- `canary/markdown.scm` — `markdown-view` returns a view node.
  Minimal implementation: headers, lists, quotes, hr. Inline bold/italic
  parsing dropped (was buggy in the old code).
- `canary/protocol.scm` — adds `<command-msg>` (keymap-produced commands)
  and `<tick-msg>` (animation hook for future use). Existing message
  classes unchanged.
- `canary/app.scm` — backend-driven render path; keymap runs in the
  event loop before user `update`; matched bindings dispatch as
  `<command-msg>`; pending swallows; misses fall through.
- `canary/components/progress.scm` — `progress-view` returns a node.
- `canary/components/spinner.scm` — `spinner-view` returns a node.
- `canary/components/textinput.scm` — `textinput-view` returns a node.
  `component-update` unchanged in behavior.

### Tests + build

- `Makefile` — `compile` / `test` / `lint` / `clean` / `repl` targets.
  `lint` greps for `\x1b` outside `backend-ansi.scm` / `terminal.scm`.
- `tests/test-chord.scm`, `test-keymap.scm`, `test-view.scm`,
  `test-render.scm`, `test-faces.scm` — all passing.

### Examples

- `examples/minimal-counter.scm` — rewritten to the new API: keymap-driven
  (`q`/`j`/`k` bound to `:quit` / `:inc` / `:dec`), `<command-msg>`
  dispatched to `update`, view returns a `vbox`/`boxed`/`txt` tree.
  Loads cleanly; runs against a real TTY.

## What did NOT land (deferred)

These modules still exist in the repo but reference symbols (e.g. old
`fg`, `bg`, `nl`, `zone-coords`) that no longer exist. They compile to
.go with warnings; calling their `*-view` / `*-render` functions will
error at runtime.

- `canary/zones.scm` — uses inline `\x1b` markers to record clickable
  rects. Incompatible with view-nodes. **Needs redesign**: attach
  zone-id metadata to nodes, have the renderer record rects as a
  side output. **Triggers `make lint` failure.**
- `canary/components/viewport.scm` — scrolls a content string. Needs
  redesign as a clipping container over a child node.
- `canary/components/paginator.scm` — string-based.
- `canary/components/canvas.scm` — depends on zones + string output.
- `canary/components/grid.scm` — string-based with old `fg`.
- `canary/components/textarea.scm` — depends on zones + string output.
- `canary/mouse.scm`, `canary/sexp-buffer.scm`, `canary/zipper.scm`,
  `canary/spring.scm` — compile clean (no view-API dependency); kept
  as-is for future use.

These examples reference deferred modules and won't run:
`art-editor`, `full-editor`, `grid-editor`, `sexp-editor`, `showcase`,
`struct-edit`, `text-editor-proper`, `four-panel-tui`. The original
plan listed `four-panel-tui` as an acceptance gate; downgraded because
`zones` needs the redesign noted above. Follow-up work.

## Acceptance criteria — actual

| Criterion                                                       | Status |
| --------------------------------------------------------------- | ------ |
| New substrate modules exist with tests                          | ✅      |
| Core view primitives rewritten                                  | ✅      |
| Chord/keymap ported and tested                                  | ✅      |
| `<command-msg>` dispatched via keymap                           | ✅      |
| `examples/minimal-counter.scm` runs against the new pipeline    | ✅      |
| `examples/four-panel-tui.scm` runs                              | ❌ (zones deferred) |
| No `\x1b` outside `backend-ansi.scm` / `terminal.scm`           | ❌ (zones deferred) |
| `<test-backend>` exists                                          | ❌ (follow-up) |

## Follow-up work

1. **Port zones** by attaching zone-id metadata to view nodes; renderer
   collects (node-id → rect) into a side table the input loop can hit-test.
   This unblocks four-panel-tui, canvas, textarea.
2. **Port viewport** as a clipping container over a child node.
3. **Port the remaining components** (paginator, canvas, grid, textarea)
   once zones lands.
4. **Add `<test-backend>`** that collects commands in a vector for
   component assertions.
5. **Rewrite the broken examples** or delete them.
