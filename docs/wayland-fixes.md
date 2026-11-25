# Wayland fixes

GNOME on Wayland deliberately blocks things X11-era tools relied on:

1. **Focus stealing:** an app can't bring its own window to the front without an activation token.
2. **Synthetic input:** apps can't type keys into other apps.
3. **Window placement:** a normal app window can't span several monitors.
4. **Background clipboard access:** GNOME (mutter) has no *data-control* protocol, so CLI tools
   must briefly show a window to read or write the clipboard.

Each fix below works around one of these limits.

---

## Clipboard manager: Clipboard Indicator

**Goal:** `Ctrl+Alt+V` opens a small history menu at the mouse pointer; you pick with keys
or mouse; it pastes into the focused app and closes.

**Why a Shell extension:** it runs inside GNOME Shell, so limits 1 and 2 don't apply to it.
CopyQ (the previous tool) runs as a normal app and couldn't focus its window or paste
reliably (see [decisions.md](decisions.md)).

**Settings** (in `gnome/dconf/shell.ini`): `toggle-menu = Ctrl+Alt+V`, `open-at-cursor`,
`paste-on-select`, `show-search-bar`, `enable-keybindings`.

**Local patch** (`gnome/patches/clipboard-indicator.patch`, three changes marked `LOCAL PATCH`):

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | Picking an **image** pasted nothing in terminals or Claude Code | Upstream sends `Shift+Insert` (`Ctrl+Shift+Insert` in terminals), which only pastes text | For images, send `Ctrl+V`, so apps that read images themselves get them |
| 2 | Picking an item pasted the **latest copy instead** | Upstream restores the previous clipboard item 50 ms after the paste key. Apps that read the clipboard asynchronously (VS Code, Chrome, Discord) read after the restore | Don't restore: the chosen item stays on the clipboard (like CopyQ) |
| 3 | The extension **silently stopped recording** copies | It awaits each clipboard format with no timeout. An XWayland owner (xclip, Flameshot) may never answer a format it doesn't offer, so a "refresh in progress" flag stays set forever | 1 s timeout per format request |

**Undo:** `mv extension.js.orig extension.js` in
`~/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/`, then log out and in.

**Known limitation:** history is stored unencrypted in
`~/.cache/clipboard-indicator@tudmotu.com/`. See [security.md](security.md#clipboard-history).

---

## `wl-copy` / `wl-paste` wrappers (`stow/desktop/.local/bin/`)

**Symptom:** a brief flash at the right edge of the screen when pressing `Ctrl+V` in Claude
Code, or when selecting text in it.

**Cause:** limit 4. Without data-control, `wl-copy` and `wl-paste` map a tiny window to get
focus. Claude Code calls `wl-paste --list-types` and `wl-paste --type <mime>` to read images
on `Ctrl+V`, and `wl-copy` / `wl-copy --primary` to copy a selection.

**Fix:** wrappers earlier in `PATH` route exactly those call shapes through `xclip`, which
uses XWayland. Mutter bridges the X11 and Wayland clipboards (both CLIPBOARD and PRIMARY, in
both directions; verified), and XWayland clients need no window or focus. Any other arguments,
or a missing `xclip` or `DISPLAY`, fall through to the real `/usr/bin/wl-*`. The `wl-copy`
wrapper detaches xclip's stdout and stderr, because xclip keeps a background process to own
the selection, and callers that capture output would otherwise wait.

**Requires:** `xclip`. `wl-clipboard` stays installed for everything else.
**Undo:** delete the two links in `~/.local/bin/` (or `stow -D desktop`).

---

## Image paste into Claude Code

Claude Code reads clipboard images itself when you press `Ctrl+V`: it runs `wl-paste` on
Wayland (`xclip` on X11). That needs a clipboard tool installed (it is: `wl-clipboard`, plus
the wrapper above). Flows that work:

- `Print` (GNOME screenshot) → `Ctrl+V` in Claude Code
- `Ctrl+Shift+Print` → select → `Ctrl+C` → `Ctrl+V` in Claude Code
- `Ctrl+Alt+V` → pick an image → pasted automatically (patch fix 1)

Text still pastes into the terminal with `Ctrl+Shift+V`.

---

## Flameshot (`Ctrl+Shift+Print`)

| Symptom | Cause | Fix |
|---|---|---|
| Capture overlay only on the main screen | Limit 3: a native Wayland window can't span monitors | Run Flameshot under XWayland (`QT_QPA_PLATFORM=xcb`): the X11 overlay can cover all screens (verified 7520×3840 across both monitors) |
| `Ctrl+C` copied nothing | Native Wayland Flameshot can't set the clipboard on GNOME (`Could not init WaylandClipboard`) | Same: under XWayland the clipboard is set through X11 and bridged |
| Still one screen after a while | `flameshot gui` hands off to a D-Bus-activated daemon, which started *without* the X11 setting | `stow/desktop/.local/share/dbus-1/services/org.flameshot.Flameshot.service` overrides the system service's `Exec` with the X11 setting |

The shortcut runs `env QT_QPA_PLATFORM=xcb flameshot gui` (custom keybinding `flameshot1`).
The first capture asks GNOME's screenshot permission; see [security.md](security.md#screenshot-permission).
**Requires** `xwayland-native-scaling` (GNOME 47+, set in `gnome/dconf/mutter.ini`) for a sharp
overlay at fractional scaling. On GNOME 46 the overlay may be slightly blurry at 150 %.
**Undo:** delete the D-Bus override link and set the shortcut command to `flameshot gui`.

---

## Crow Translate (`Ctrl+Alt+E/S/F/G/C/I/O`)

`bin/crow-wayland` bridges GNOME custom shortcuts to Crow's D-Bus API
(`io.crow_translate.CrowTranslate`), because Crow's own global shortcuts don't work on
Wayland. OCR uses GNOME's screenshot portal plus `tesseract`, then hands the text to Crow
through the primary selection.

| Symptom | Cause | Fix |
|---|---|---|
| Crow's window stayed **behind** other windows | Limit 1: the D-Bus call carries no activation token, so GNOME refuses Crow's focus request. A first attempt that reacted to the "demands attention" signal didn't work | `focus-allowlist@local`, a ~70-line Shell extension, exports `org.gnome.Shell /local/FocusAllowlist local.FocusAllowlist.Activate("crow")`. `crow-wayland` calls it after translate, show or OCR translate. Only allow-listed apps can be raised; every other app keeps GNOME's protection |
| Crow **flashed** hidden/shown when clicking another window | `crow-wayland` raised Crow twice (at 0.3 s and 1 s); the second raise pulled it back | Raise once at 0.2 s, retrying only while Crow's window isn't visible yet (`Activate` returns false) |
| Copy from OCR flashed at the screen edge | Limit 4 (`wl-copy`) | `crow-wayland` uses `xclip` (clipboard and primary), and waits 0.2 s for mutter to bridge the primary selection before Crow reads it |

To allow another app, add its WM class or app id to `APPS` in the extension's
`extension.js`, call `Activate("<key>")` from your script, then log out and in.
`DEBUG = true` logs `[focus-allowlist]` lines to `journalctl --user`.

---

## Display scaling

`gnome/dconf/mutter.ini` enables `scale-monitor-framebuffer` (fractional scaling) and
`xwayland-native-scaling`, so XWayland apps (Flameshot, xclip-based tools) render at native
resolution instead of being upscaled.
