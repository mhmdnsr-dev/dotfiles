# Troubleshooting

Start with the general checks, then find the symptom below.

```sh
cd ~/dotfiles
stow -n --no-folding -d stow -t ~ $(ls stow)        # links intact? (no output = yes)
gnome-extensions list --enabled                      # extensions loaded?
journalctl --user -b | grep -iE 'JS ERROR|clipboard-indicator|focus-allowlist' | tail
```

Remember: **extension code changes only load after logging out and back in** (Wayland).

## Clipboard (`Ctrl+Alt+V`)

| Symptom | Check | Fix |
|---|---|---|
| Menu doesn't open | `gnome-extensions info clipboard-indicator@tudmotu.com` shows `ACTIVE`? Is the shortcut taken by something else? | Enable the extension; `./install.sh` re-applies the shortcut |
| Pastes the latest copy, not the picked item | `grep -c 'LOCAL PATCH' …/clipboard-indicator@tudmotu.com/extension.js` should be `3` | The patch is missing (often after an extension update): `./install.sh`, log out and in. See [maintenance.md](maintenance.md#after-a-clipboard-indicator-update) |
| New copies stop appearing in the history | Same patch check (fix 3, the hang guard) | Short term: `gnome-extensions disable clipboard-indicator@tudmotu.com && gnome-extensions enable clipboard-indicator@tudmotu.com`. Long term: re-apply the patch |
| Picking an image pastes nothing | Patch fix 1 present? Does the target app read images on `Ctrl+V`? | Plain shells can't paste images; Claude Code, browsers and editors can |
| Menu opens but the paste lands in the wrong place | Was the target window focused before pressing `Ctrl+Alt+V`? | Click into the target field first |

## Flashes at the screen edge

| Symptom | Check | Fix |
|---|---|---|
| Flash on `Ctrl+V` or text selection in Claude Code | `which wl-copy wl-paste` → `~/.local/bin/…`? `which xclip`? | `stow --no-folding -d stow -t ~ desktop`; `sudo apt install xclip` |
| Flash from another tool | It calls the real `wl-copy`/`wl-paste` with other arguments | Expected: the wrappers only reroute the call shapes Claude Code uses. Extend the `case` in the wrapper if needed |

## Flameshot (`Ctrl+Shift+Print`)

| Symptom | Check | Fix |
|---|---|---|
| Overlay only on one monitor | `pgrep -a flameshot`, then `tr '\0' '\n' </proc/<pid>/environ \| grep QT_QPA` should show `xcb` | A daemon started without it: `pkill -x flameshot`, check that the D-Bus override link exists in `~/.local/share/dbus-1/services/`, then try again |
| `Ctrl+C` copies nothing | Same check | Same fix |
| Asks "Allow screenshot?" every time | Portal permission store | Click Allow once; it's stored. See [security.md](security.md#screenshot-permission) |
| Blurry overlay | GNOME 46 lacks `xwayland-native-scaling` | Expected on 24.04 at fractional scaling |

## Crow Translate

| Symptom | Check | Fix |
|---|---|---|
| Shortcut does nothing | `~/.local/bin/crow-wayland translate` in a terminal: any error? Is `crow` running? | `crow-wayland start`; check Crow's autostart entry exists |
| Window stays behind others | `gdbus call --session --dest org.gnome.Shell --object-path /local/FocusAllowlist --method local.FocusAllowlist.Activate crow` returns `(true,)`? | If the method is unknown, the extension isn't loaded: `gnome-extensions info focus-allowlist@local`, check `shell-version` in its `metadata.json`, log out and in |
| Window flashes hidden/shown | Did `raise_crow` get edited back to raising twice? | It must raise once (see [wayland-fixes.md](wayland-fixes.md#crow-translate-ctrlaltesfgcio)) |
| OCR translates the previous selection | The 0.2 s bridge delay is too short on a slow machine | Increase `sleep 0.2` before `call translateSelection` in `crow-wayland` |
| OCR finds no text | `tesseract --list-langs` includes your language? | `sudo apt install tesseract-ocr-<lang>`; set `CROW_OCR_LANGS=eng+ara` |

To debug the focus extension, set `DEBUG = true` in its `extension.js`, log out and in, and
read `journalctl --user -b | grep focus-allowlist`.

## Dotfiles / install

| Symptom | Fix |
|---|---|
| `stow` reports a conflict | An app replaced a link with a real file: merge its content into `stow/`, delete it, re-stow |
| `install.sh` says the patch was skipped | The extension version changed and the patch no longer fits: re-port it ([maintenance.md](maintenance.md#after-a-clipboard-indicator-update)) |
| `snapshot.sh` exits with "review the lines above" | A home path or secret-looking value reached a copied file: scrub it (extend the scrub list in `snapshot.sh`) |
| `snap list` hangs | Known on this machine. `snapshot.sh` reads `/snap` instead of calling `snap list` |
| New shell prints `ng: command not found` | `.zshrc` only loads Angular completion when `ng` exists; make sure you're on the current `.zshrc` |
