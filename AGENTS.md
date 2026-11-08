# AGENTS.md

Instructions for coding agents working in this repository.

## What this is

A REAPER configuration package that makes REAPER's mouse and wheel behaviour
match Cubase's. Two independent mechanisms, often confused:

| What | Where it lives | How to change it |
|---|---|---|
| Mouse modifiers (click/drag behaviour) | `<resource>/reaper-mouse.ini` | ReaScript `reaper.SetMouseModifier` |
| Wheel zoom/scroll | `<resource>/reaper-kb.ini`, `KEY 255 ...` lines | `tools/apply_wheel.py` or REAPER's Actions window |
| Keyboard shortcuts | `<resource>/reaper-kb.ini`, `KEY ...` lines | `.ReaperKeyMap` import |

The wheel is **not** part of the mouse-modifier system. `Preferences → Mouse
Modifiers` has no wheel settings. Do not try to solve wheel problems with
`SetMouseModifier`.

## Layout

```
scripts/
  Cubase_mouse_modifiers.lua     applies 24 mouse-modifier bindings (idempotent)
  Restore_REAPER_defaults.lua    resets only those 24 positions
tools/
  apply_wheel.py                 writes/removes the 8 wheel bindings (idempotent)
docs/
  wheel-bindings.txt             the 8 lines, for manual append
  mapping-table.zh-CN.md         per-context binding table (Chinese)
skill/
  SKILL.md                       Hermes/agent skill describing the whole procedure
```

## Ground truth for behaviour names

Do not invent mouse-modifier action names. Two authoritative sources:

1. Extract from `reaper.exe`: grep for `Set default mouse modifier action for "..." to "..."`.
   Every match is a valid (context, behaviour) pair for that build.
2. The 935 generator scripts REAPER ships (`Set default mouse modifier action for ... .lua`).

After any write, read back with `reaper.GetMouseModifier(context, flag)`.
An empty string or `-1` means the write was rejected — most often because the
context name or behaviour name is wrong for that REAPER version.

## Context-name gotchas

These names contain a slash. Writing them with a space silently fails:

- `MIDI CC lane left click/drag`
- `MIDI CC event left click/drag`
- `Media item fade/autocrossfade left drag`

These three contexts accept numeric IDs only in REAPER 7.83 — behaviour names
read back as `0`. Do not add them:

- `Project tempo/time signature marker left drag`
- `Project marker/region edge left drag`
- `Project region left drag`

## Wheel keycodes

`KEY 255 <keycode> <action_id> <section>`, sections `0` = Main, `32060` = MIDI Editor.

Keycode = `248 + modifier bits` (ctrl=1, alt=2, shift=4). REAPER 7 writes the high
form (low + 9984). Both are accepted. See `tools/apply_wheel.py` for the table.

Horizontal scroll must use the **reversed** action (977 / 40660). The forward
version (988 / 40433) scrolls opposite to Cubase.

## Verifying changes

Do not stop at "the script ran without error". Real verification:

1. **Headless ReaScript.** REAPER auto-runs `<resource>/Scripts/__startup.lua`
   (inside `Scripts/`, not the resource root). Load your script there, write
   results to a file, then `reaper.Main_OnCommand(40004, 0)` to quit:

   ```lua
   _G.HEADLESS_OUT = [[C:\path\to\result.txt]]
   local ok, err = pcall(dofile, [[C:\path\to\your_script.lua]])
   if not ok then
     local f = io.open(_G.HEADLESS_OUT, "w")
     if f then f:write("ERR "..tostring(err)) f:close() end
   end
   reaper.defer(function() reaper.Main_OnCommand(40004, 0) end)
   ```

   Have the loaded script write to `_G.HEADLESS_OUT` when set, and call
   `ShowMessageBox` otherwise.

2. **Real wheel events.** `computer_use` usually times out on REAPER's UIA tree.
   Post wheel messages directly via Win32 (`WM_MOUSEWHEEL` = `0x020A`,
   `120` = up, `-120` = down, `wParam = delta << 16`, `lParam = y << 16 | x`).
   Hold modifiers with `keybd_event` (0x11 = Ctrl, 0x10 = Shift, 0x12 = Alt).

3. **Observe with `GetSet_ArrangeView2(0, false, 0, 0)`** which returns `start, end`:
   - horizontal zoom → `end - start` changes, `start` stays
   - horizontal scroll → `end - start` stays, `start` changes
   - vertical zoom/scroll → neither changes (use exclusion to infer)

4. **`apply_wheel.py` self-checks.** `--verify-only` exits non-zero when bindings
   are missing, so CI or an agent can assert on the exit code.

## Testing the wheel tool without touching a real install

`--resource` accepts any directory:

```bash
mkdir -p /tmp/fake-reaper && cp <real>/reaper-kb.ini /tmp/fake-reaper/
python tools/apply_wheel.py --resource /tmp/fake-reaper --dry-run
python tools/apply_wheel.py --resource /tmp/fake-reaper
python tools/apply_wheel.py --resource /tmp/fake-reaper --verify-only
python tools/apply_wheel.py --resource /tmp/fake-reaper --revert
```

Expected: apply reports `removed N, added 8` and `verify: OK`; a second apply
reports `already up to date, nothing written`; revert reports `verify: OK
(bindings absent as requested)`.

## Constraints

- REAPER rewrites `reaper-kb.ini` on exit. Both scripts must run with REAPER
  **closed** or the changes are lost.
- Never write credentials, tokens, or personal paths into this repo.
- `apply_wheel.py` and the Lua scripts must stay idempotent — re-running them
  must not duplicate lines or create spurious backups.
- Back up before writing. `apply_wheel.py` does this automatically; the Lua
  apply script copies `reaper-mouse.ini` to `MouseMaps/backup-<timestamp>.ReaperMouseMap`.

## What cannot be reproduced

- **Alt+click-then-drag to set event length.** REAPER treats click and drag as
  separate contexts. Alt+click inserts a fixed-length item; Alt+drag draws one.
  There is no single gesture for both.
- **Tool modes.** Cubase's Split/Erase/Range are tool states. REAPER has no tool
  state, only modifier combinations.
- **Eraser.** Cubase has no default modifier for it; REAPER's native
  right-drag-to-erase is left untouched on purpose.
