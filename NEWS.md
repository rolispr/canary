# Canary news

Changes are listed newest-first.  Format follows
[Keep a Changelog](https://keepachangelog.com).

## 0.2.0 — unreleased

### Fixed

- **Pending-wrap (LCF) at the right margin.**  The terminal emulator
  in `canary/term/` now follows the VT100/xterm spec for autowrap.
  Printing a character at the last column sets a pending-wrap flag
  rather than walking the cursor off the grid; the next print
  consumes the flag (wrapping to column 0 of the next row when
  DECAWM is on, overwriting the last cell when DECAWM is off).
  Any explicit cursor movement (CR, LF, CUP, CUU, CUD, CUF, CUB,
  HPA, VPA, HT, HBT, IND, RI) clears the flag.  Save and restore
  cursor preserve it.

  This corrects a column-edge bug: previously, printing at the last
  column advanced the cursor past the right margin and the next
  print eager-wrapped, producing wrong cell positions for any output
  that relied on the spec behaviour.
