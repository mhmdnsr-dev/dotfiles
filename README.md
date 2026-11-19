# dotfiles: GNOME Wayland desktop setup

My Ubuntu 26.04 / GNOME 50 (Wayland) desktop tooling: a keyboard-first clipboard
manager, multi-monitor screenshots, and Crow Translate shortcuts that actually work on Wayland.

## What you get

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+V` | Clipboard history pops up at the mouse pointer; pick with keys or mouse; it pastes (text **or image**) and closes |
| `Ctrl+Shift+Print` | Flameshot area capture across **all monitors**; `Ctrl+C` puts the image on the clipboard |
| `Print` | GNOME screenshot (also lands in the clipboard history) |
| `Ctrl+Alt+E` / `S` / `F` / `G` | Crow: translate / speak / speak translation / stop |
| `Ctrl+Alt+C` | Crow main window, raised to the front |
| `Ctrl+Alt+I` / `O` | OCR a screen area: copy the text / translate it |
| `Ctrl+I` | Emoji picker (Smile, Flatpak) |

## Install

```sh
sudo apt install xclip wl-clipboard flameshot crow-translate tesseract-ocr python3-gi
git clone https://github.com/mhmdnsr-dev/dotfiles ~/dotfiles
~/dotfiles/install.sh        # accept the GNOME prompt to install Clipboard Indicator, then re-run
# log out and back in
```

`install.sh` is safe to re-run. Anything it would replace is kept as `*.pre-dotfiles`.

## Why each piece exists (the Wayland problems)

GNOME on Wayland deliberately blocks three things that X11-era desktop tools rely on:
stealing focus, synthesising key presses, and placing windows across monitors. It also
lacks the *data-control* protocol that clipboard CLIs use. Each piece here works around one of those.

- **Clipboard: [Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator/)**
  runs inside GNOME Shell, so it can open at the pointer and paste without `ydotool`/uinput.
  [`gnome-shell/patches/`](gnome-shell/patches/) adds two fixes on top of v74:
  1. **Image paste:** for images, send `Ctrl+V` and keep the image on the clipboard.
     Upstream sends `Shift+Insert`, which terminals treat as text-only, then restores the
     previous item after 50 ms, before an app like Claude Code has read the image.
  2. **Hang guard:** a 1 s timeout per clipboard-format request. An XWayland owner
     (xclip, Flameshot) may never answer a format it doesn't offer, and upstream then
     stops recording every later copy without any error.
- **`bin/wl-copy`, `bin/wl-paste`:** without data-control, `wl-copy` and `wl-paste` briefly map a
  window to grab focus, which shows as a flash at the screen edge. These wrappers route the simple
  calls (the ones Claude Code makes for select-to-copy and image paste) through `xclip`
  via XWayland, which needs no window. Anything else falls through to the real binaries.
- **Flameshot:** a native Wayland window can't span monitors, and native mode can't set the
  clipboard on GNOME. [`flameshot/org.flameshot.Flameshot.service`](flameshot/) makes the
  D-Bus-activated daemon run under XWayland (`QT_QPA_PLATFORM=xcb`), so `flameshot gui`
  covers every screen and `Ctrl+C` works.
- **Crow Translate: [`bin/crow-wayland`](bin/crow-wayland)** bridges GNOME shortcuts to Crow's
  D-Bus API. It does OCR through the screenshot portal and tesseract, and copies with xclip.
  GNOME refuses Crow's own focus request (it comes with no activation token), so
  **[`focus-allowlist@local`](gnome-shell/extensions/focus-allowlist@local/)**, a tiny Shell
  extension, exposes `local.FocusAllowlist.Activate("crow")` and raises Crow's window, for
  allow-listed apps only. Every other app keeps GNOME's focus-stealing protection.
- **[`gnome/settings.sh`](gnome/settings.sh):** custom shortcuts, Clipboard Indicator options,
  fractional scaling and `xwayland-native-scaling`, so XWayland apps stay sharp.

## Keeping the repo current

Symlinked files (`bin/*`, the focus extension, the Flameshot D-Bus override) are edited in
place, so just commit. Copied files (Flameshot and Crow configs, the Clipboard Indicator patch)
are refreshed with:

```sh
./snapshot.sh && git diff
```

`snapshot.sh` scrubs Crow's API key, proxy credentials, window geometry and home paths, and
refuses to finish if anything secret-looking is left.

## Caveats

- An extension update overwrites the Clipboard Indicator patch. Re-run `install.sh`; if the
  version changed, the patch must be re-ported.
- The clipboard history is stored unencrypted in `~/.cache/clipboard-indicator@tudmotu.com/`.
  Use its private mode, or delete entries, for secrets.
- `Ctrl+Alt+V` image paste in a terminal relies on the app reading images on `Ctrl+V`
  (Claude Code does). Plain shells can't paste images.
