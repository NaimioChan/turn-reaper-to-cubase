# turn-reaper-to-cubase

Make REAPER's mouse and wheel behave like Cubase's.

Two things are configured independently, because REAPER stores them in different places:

- **Mouse modifiers** — click and drag behaviour (24 bindings), set by a ReaScript.
- **Wheel** — zoom and scroll (8 bindings), written into `reaper-kb.ini`.

The wheel is *not* part of the mouse-modifier system; `Preferences → Mouse Modifiers` has no wheel settings.

## What you get

| Wheel | Action |
|---|---|
| Ctrl+wheel | zoom horizontally |
| Ctrl+Shift+wheel | zoom vertically |
| Shift+wheel | scroll horizontally (direction matches Cubase) |
| wheel | scroll vertically |

| Context | Modifier | Behaviour |
|---|---|---|
| Item click | — / Ctrl | select / toggle selection |
| Item drag | — / Ctrl / Alt / Ctrl+Alt | move / move ignoring snap / copy / copy ignoring snap |
| Empty track click | Alt / Ctrl+Alt | no action (leaves the drag context free) |
| Empty track drag | — / Ctrl | marquee select / toggle selection |
| Empty track drag | Alt / Ctrl+Alt | draw empty MIDI item / draw ignoring snap |
| MIDI note click | — / Ctrl | select / toggle selection |
| MIDI note drag | — / Ctrl / Alt / Ctrl+Alt | move / move ignoring snap / copy / copy ignoring snap |
| Piano roll click | Alt / Ctrl+Alt | no action (leaves the drag context free) |
| Piano roll drag | — / Ctrl | marquee select notes / toggle selection |
| Piano roll drag | Alt / Ctrl+Alt | insert note and drag / insert ignoring snap |
| CC / velocity lane drag | — / Ctrl | draw or edit CC / marquee select |
| CC / velocity lane drag | Alt / Ctrl+Alt | insert CC event / insert ignoring snap |
| CC event drag | — / Ctrl / Alt / Ctrl+Alt | move / move ignoring snap / copy / copy ignoring snap |
| CC event drag | Ctrl+Shift | edit CC events |
| CC segment drag | — / Ctrl / Alt / Ctrl+Alt | move / edit curvature / insert point / insert ignoring snap |

Applies to the arrange view, the MIDI editor, and the CC/velocity lanes (velocity is a CC lane, so the same three contexts cover both). Full table: `docs/mapping-table.zh-CN.md`.

Eraser behaviour is left as REAPER's native (right-drag) — Cubase has no default modifier for it.

## Install

Requires REAPER 7.x. **Close REAPER first** — it rewrites `reaper-kb.ini` on exit, so changes made while it is running are lost.

### 1. Mouse modifiers

Open the Actions window (`?`), click `New action` → `Load ReaScript...`, pick
`scripts/Cubase_mouse_modifiers.lua`, then select it and click `Run`.

The script backs up `reaper-mouse.ini` to `MouseMaps/backup-<timestamp>.ReaperMouseMap` before writing, then reads every value back and reports:

```
total 24 | changed 21 | already correct 3 | failed 0
```

`failed` must be 0. A non-zero count means a behaviour name does not exist in your REAPER build; the dialog names the offending line.

### 2. Wheel bindings

```bash
python tools/apply_wheel.py
```

It detects the resource directory per platform, or pass `--resource PATH`.
Writes 8 lines, backs up first, then verifies by reading the file back.

```bash
python tools/apply_wheel.py --dry-run       # show what would change
python tools/apply_wheel.py --verify-only   # exit 1 if bindings are missing
python tools/apply_wheel.py --json          # machine-readable
```

No Python? Append the contents of `docs/wheel-bindings.txt` to `reaper-kb.ini` manually.

Either way, the equivalent GUI route is: Actions window → find the action → `Add...` → roll the wheel with the modifier held. REAPER writes the keycode itself.

## Uninstall

- Mouse modifiers: run `scripts/Restore_REAPER_defaults.lua`. It resets only the 24 positions this package touched.
- Wheel: `python tools/apply_wheel.py --revert`, or delete the lines from `docs/wheel-bindings.txt`.

## Verification

The wheel tool verifies itself: `--verify-only` exits non-zero when bindings are missing.

To confirm by hand, watch the arrange view:

- Ctrl+wheel changes the horizontal span, not the start position.
- Shift+wheel changes the start position, not the span.

## Known limits

- **Tool modes** (Split, Erase, Range) do not exist in REAPER. Only single-gesture actions survive as modifier combinations.
- Three contexts accept numeric IDs only in REAPER 7.83, so tempo markers, project marker edges, and project regions are not covered.

Alt+click-then-drag is handled: the Alt and Ctrl+Alt *click* slots are `No action` in
both the arrange view and the piano roll, so the press falls through to the drag
context and one gesture draws the item or note and sets its length.

## For agents

`AGENTS.md` documents the file formats, the keycode table, the context-name traps, and how to verify without a GUI. `skill/SKILL.md` is the same procedure packaged as a Hermes skill.

Testing the wheel tool without touching a real install:

```bash
mkdir -p /tmp/fake-reaper && cp "$APPDATA/REAPER/reaper-kb.ini" /tmp/fake-reaper/
python tools/apply_wheel.py --resource /tmp/fake-reaper
python tools/apply_wheel.py --resource /tmp/fake-reaper --verify-only
```

## License

MIT
