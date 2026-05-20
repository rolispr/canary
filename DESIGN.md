# canary — design

A live-coded TUI library for Guile. Elm-style loop with a typed view tree.

Two bets that shape every decision:

1. **View is a tree, not a styled string.** Composition, overlays, sizing
   and diffing are engine primitives. The user describes structure; the
   engine handles cells. This is the axis tea+lipgloss don't cover — they
   hand the user strings to concatenate and styles to chain.

2. **Styling is a palette + boolean flags.** `#:fg`/`#:bg` accept a hex
   string *or* a palette name (`#:fg 'accent`). Attribute flags are
   individual booleans (`#:bold`, `#:italic`). Multiple palettes register
   under one theme; `(cycle-palette)` swaps the active one and every
   palette-named reference recolors. No `if dark-mode-then` at call sites,
   no separate style-name layer.

Aim: clearer than tea+lipgloss for visual/composable TUIs, with REPL-driven
iteration. Not optimising for smallest binary, lowest baseline CPU, or
ecosystem size.

## Architecture

An app is a GOOPS class extending `<app>`. The Elm loop is three generics
specialised on the user's subclass:

```scheme
init   : <app>          → cmd
update : <app> msg size → (values app cmd)
view   : <app> size     → view-node
```

The engine calls them as `(init the-app)`, `(update the-app msg sz)`,
`(view the-app sz)`. Generic dispatch on the app class resolves to the
user's methods. There is no kwarg-proc plumbing.

The engine:

- runs the channel-backed event loop
- reads input (keys, mouse) and emits typed msgs
- dispatches msgs through an optional filter then to `update`
- renders the view tree after each dispatch (no fixed-fps render loop)
- spawns fibers for cmds that need them (`every`, `after`, user thunks)

Method names are looked up by generic at every call, so redefining a method
at the REPL takes effect on the next event.

## A "hello, world" app

```scheme
(use-modules (canary))

(define-class <hello> (<app>)
  (greeting #:init-value "world" #:accessor hello-greeting))

(define-method (view (h <hello>) sz)
  (align (txt "hello, " (txt (hello-greeting h) #:fg 'accent #:bold))
         'center #:width (size-width sz)))

(run-app (make <hello>
              #:keymap (keymap (bind #\q 'quit))))
```

Everything else has defaults: `init` returns `#f`, `update` returns
`(values app #f)`, all UI state is engine-managed (alt-screen on, cursor
hidden, mouse off, title = program name).

## `<app>` base class

User subclasses extend this. Slots define both static config (`#:keymap`,
`#:theme`, `#:title`, ...) and the user's own model fields.

```scheme
(define-class <app> ()
  (title       #:init-keyword #:title       #:init-value #f
               #:accessor app-title)
  (keymap      #:init-keyword #:keymap      #:init-value (keymap)
               #:accessor app-keymap)
  (theme       #:init-keyword #:theme       #:init-value #f
               #:accessor app-theme)
  (alt-screen? #:init-keyword #:alt-screen? #:init-value #t
               #:accessor app-alt-screen?)
  (cursor      #:init-keyword #:cursor      #:init-value 'hidden
               #:accessor app-cursor)
  (mouse       #:init-keyword #:mouse       #:init-value 'off
               #:accessor app-mouse)
  (filter      #:init-keyword #:filter      #:init-value #f
               #:accessor app-filter)
  (backend     #:init-keyword #:backend     #:init-value #f
               #:accessor app-backend))
```

User subclasses add their own slots:

```scheme
(define-class <tweet> (<app>)
  (frame #:init-value 0   #:accessor tweet-frame)
  (notes #:init-value '() #:accessor tweet-notes)
  (input #:init-form (make-textinput …) #:accessor tweet-input))
```

`run-app` accepts any `<app>` instance:

```scheme
(run-app (make <tweet>
              #:title  "canary tweet"
              #:keymap %keymap
              #:theme  ui
              #:mouse  'cell))
```

## Default methods

`<app>` ships with default methods so a barebones subclass works:

```scheme
(define-method (init   (m <app>))        #f)
(define-method (update (m <app>) msg sz) (values m #f))
(define-method (view   (m <app>) sz)     (txt ""))
```

User overrides any subset by specialising on their subclass.

## Msgs

Records produced by the engine, matched by `update`.

| record       | when                                          |
|--------------|-----------------------------------------------|
| `<key>`      | a keystroke (with optional modifiers)         |
| `<mouse>`    | mouse button / motion / scroll                |
| `<tick>`     | an `every` or `after` fired                   |
| `<resize>`   | terminal size changed                         |
| `<focus>`    | terminal gained focus                         |
| `<blur>`     | terminal lost focus                           |
| `<suspend>`  | engine about to release tty (after Ctrl-Z)    |
| `<resume>`   | engine reacquired tty                         |
| symbol       | keymap action; user-issued msg                |
| list         | any user-defined shape via `(send app …)`     |

Multi-method dispatch on msg records gives one `update` per case:

```scheme
(define-method (update (m <tweet>) (msg <tick>)  sz) …)
(define-method (update (m <tweet>) (msg <key>)   sz) …)
(define-method (update (m <tweet>) (msg <mouse>) sz) …)
```

Symbols and lists need a catch-all method with internal `match`:

```scheme
(define-method (update (m <tweet>) msg sz)
  (match msg
    ('cycle-palette (values m (cycle-palette)))
    ('redraw        (values m (clear-screen)))
    (_              (values m #f))))
```

(Use `(next-method)` if you want to fall through to the type-specialised
methods after a symbol catch-all.)

## Cmds

Returned as values from `init` and `update`. Cmds are constructor calls,
not quoted literals.

| cmd                                 | effect                                  |
|-------------------------------------|-----------------------------------------|
| `#f`                                | no-op                                   |
| `'quit`                             | exit run-app                            |
| `(batch c1 c2 …)`                   | parallel                                |
| `(sequence c1 c2 …)`                | sequential, awaits each                 |
| `(every #:hz N producer)`           | persistent ticker — one fiber, no reschedule |
| `(every #:ms N producer)`           | same                                    |
| `(every #:seconds S producer)`      | same                                    |
| `(after #:ms N producer)`           | one-shot timer                          |
| `(println "string" …)`              | line to scrollback above alt-screen     |
| `(set-title "name")`                | runtime OS title change                 |
| `(clear-screen)`                    | force full repaint                      |
| `(cursor 'hidden│'visible│'bar│'underline)` | runtime cursor change           |
| `(alt-screen 'on│'off)`             | runtime alt-screen toggle               |
| `(mouse 'off│'click│'cell│'all)`    | runtime mouse mode change               |
| `(set-palette 'name)`               | switch active palette                   |
| `(cycle-palette)`                   | next palette in theme's declared order  |
| `(suspend)`                         | hand tty to shell, resume on SIGCONT    |
| `(exec "cmd args" #:on-done thunk)` | tear down, run process, restore, msg    |
| user thunk                          | engine spawns fiber; thunk returns msg  |

The engine intercepts `'quit` directly. Everything else flows through
`update`.

## Keys and keymap

```scheme
(keymap
 (bind k1 [k2 …] action [#:timeout-ms N])
 …)
```

A key is one of:

| form                                  | meaning                              |
|---------------------------------------|--------------------------------------|
| `#\h`, `#\?`, `#\:`                   | literal char                         |
| `#\tab`, `#\escape`, `#\space`, `#\return`, `#\delete`, `#\backspace` | Guile's built-in named chars |
| `'left`, `'right`, `'up`, `'down`, `'home`, `'end`, `'pgup`, `'pgdn`, `'f1`…`'f12` | symbols for keys without literals |
| `'(#\x ctrl)`, `'(left ctrl)`, `'(#\tab shift)` | modifier list           |
| `'(mouse left)`, `'(mouse right)`, `'(mouse middle)` | mouse button         |
| `'(mouse-scroll up)`, `'(mouse-scroll down)` | scroll wheel                  |

Modifiers: `control` / `ctrl`, `alt` / `meta` / `option`, `shift`,
`super` / `cmd` / `command`. Canonicalised, sorted, deduped internally.

Bindings:

```scheme
(bind #\q 'quit)                          ; single key
(bind 'escape 'cancel)                    ; named key
(bind '(#\x ctrl) 'cut)                   ; modified
(bind #\g #\g 'top #:timeout-ms 500)      ; sequence with timeout
(bind '(#\x ctrl) '(#\s ctrl) 'save)      ; modified sequence
(bind '(mouse left) 'select)              ; mouse
```

Last positional arg is the action. `#:timeout-ms` resets pending state if
the next key doesn't arrive in time.

The action can be any value. `'quit` is engine-intercepted. Anything else
is dispatched to `update` as a msg.

## Theme

One concept: named palettes of hex colors. Multiple palettes can register
under one theme; `(cycle-palette)` walks them.

```scheme
(define ui
  (theme
   (palette dark
     (bg     "#0a0d18")
     (fg     "#d8d2c2")
     (muted  "#5a6378")
     (accent "#ffd05e")
     (note   "#ff6b9d"))

   (palette light
     (bg     "#f8f5ec")
     (fg     "#1a1a1a")
     (muted  "#605850")
     (accent "#a06b14")
     (note   "#c01666"))))
```

Rules:

- `palette` blocks list named hex colors. First declared is the default.
- Every palette must define the same set of names. Names not present in
  every palette fall back to the default palette's value when swapped.
- Engine tracks the registered palettes; `(cycle-palette)` and
  `(set-palette 'light)` work without the user maintaining a list.

There is no style-name layer. To reuse a styling combo, define a helper:

```scheme
(define (hint s) (txt s #:fg 'muted #:italic))
(define (note s) (txt s #:fg 'note  #:bold))
```

Helpers are ordinary procs in user code, not a separate engine concept.

## View nodes

`txt` accepts strings, nested `txt` nodes (inline spans), and styling
kwargs:

```scheme
(txt "hello")
(txt "hello" #:fg 'accent #:bold)
(txt "saved: " (txt name #:fg 'note #:bold))   ; nested = inline span
(txt "tmp" #:fg "#ff0000")                     ; inline hex
```

Kwargs:

- `#:fg` / `#:bg` — hex string (`"#abc123"`) or palette name (`'accent`)
- `#:bold` `#:italic` `#:underline` `#:reverse` `#:strike` `#:dim` —
  individual boolean flags. **No `#:attrs '(bold italic)` list.**

Layout primitives:

```scheme
(vbox a b c)
(hbox a b c)
(spacer n)                       ; height in vbox
(spacer #:w n)                   ; width  in hbox
(pad    child #:top n #:left n …)         ; inner whitespace
(margin child #:top n #:left n …)         ; outer whitespace
(align  child 'left│'center│'right #:width n)
(width  child n)
(height child n)
(fill   w h #:bg 'name-or-hex)
(pin    col row child)
(overlay base p1 p2 …)
(boxed  child #:border border-rounded #:fg 'name-or-hex)
(static child)                   ; cache rendered cmds keyed on the rect
```

`pad` and `margin` are distinct on purpose: `pad` adds space *inside* a
boxed/styled region, `margin` adds space *outside*. Lipgloss conflates
them; canary keeps them separate.

## Components

Each is a GOOPS class with a `react` method:

```scheme
(define-method (react (c <my-component>) msg) …)
```

Embed in an app slot, forward explicitly from `update`:

```scheme
(define-class <tweet> (<app>)
  (input #:init-form (make-textinput …) #:accessor tweet-input))

(define-method (update (m <tweet>) (msg <key>) sz)
  (react (tweet-input m) msg)
  (values m #f))
```

No reflection over slots, no auto-delegate. Components compose by being
ordinary records embedded in the user's app class.

Bundled: `<spinner>`, `<progress>`, `<textinput>`, `<textarea>`,
`<paginator>`, `<viewport>`. Planned: `<list>`, `<help>` (renders a keymap
into a hint footer), `<filepicker>`.

## Live coding

```
make run
```

Launches the app and exposes a Geiser-listenable Guile image on
`localhost:37146`. From an Emacs/VS Code Geiser session:

- redefine an `update` / `view` / `init` method — next msg uses the new
  method (generic dispatch picks up the new definition)
- mutate slots of the live app instance directly between events
- re-evaluate the theme to swap palettes or restyle

No rebuild loop. The instance and process state survive code changes.

## Anti-patterns

- **Don't** define `init` / `update` / `view` as standalone procs and
  pass them via kwarg. They're methods on the app class.
- **Don't** construct cmds as quoted lists: `'(set-title "x")` ✗,
  `(set-title "x")` ✓.
- **Don't** put style flags in a list: `#:attrs '(bold italic)` ✗,
  `#:bold #:italic` ✓.
- **Don't** thread palette lists in user code. Declare palettes inside
  `theme`; `cycle-palette` iterates them.
- **Don't** look for a `#:style` kwarg on `txt`. Reference palette colors
  through `#:fg`/`#:bg`; bundle reuse with a helper proc.
- **Don't** poll for state changes. Every transition is a msg; every
  side-effect is a cmd.
- **Don't** issue `(alt-screen 'on)` / `(cursor 'hide)` / `(set-title …)`
  from `init` for the defaults. They're slots on the app class with the
  right defaults.
- **Don't** reach into engine state from user code. For runtime changes,
  emit a cmd.

## What canary doesn't try to do

- A statically-typed API. Match patterns and GOOPS classes are honest
  about the dynamic-Scheme nature.
- A single statically-linked binary. The runtime is Guile + fibers.
- Sub-millisecond idle CPU. Native Go beats this in absolute terms; the
  intentional trade is REPL-driven dev and a richer view IR.
- A wide ecosystem of pre-built widgets. The bundled components cover the
  common cases; the design favours composition over a sprawling library.

## Module surface

```scheme
(use-modules (canary))
```

Re-exports every public name from:

- `(canary app)`           — `<app>`, `run-app`, generic stubs for `init`,
                             `update`, `view`, `send`
- `(canary protocol)`      — msg + cmd types/constructors
- `(canary key)`           — `<key>`, `key`, `key=?`, modifier helpers
- `(canary keymap)`        — `keymap`, `bind`
- `(canary theme)`         — `theme`, palette forms
- `(canary layout)`        — `txt`, `vbox`, `hbox`, `spacer`, `pad`,
                             `margin`, `align`, `width`, `height`, `fill`,
                             `pin`, `overlay`, `static`, `boxed`
- `(canary borders)`       — `border-normal`, `border-rounded`,
                             `border-thick`, `border-double`, `border-ascii`
- `(canary backend-ansi)`  — `make-ansi-backend`
- `(canary component)`     — `<component>`, `react`, focus accessors

Components are imported individually:

```scheme
(use-modules (canary)
             (canary components textinput)
             (canary components spinner))
```
