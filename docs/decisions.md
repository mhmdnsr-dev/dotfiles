# Decision log

Newest first. Each entry gives what was decided, why, and what was rejected.

## 2026-11-25

- **Documentation added** (`docs/`), split by question: architecture, new machine,
  maintenance, fixes, troubleshooting, security, packages, decisions.
- **Support Ubuntu 24.04 (GNOME 46) as well as 26.04.** Checked 24.04's versions: Clipboard
  Indicator v71 (the patch applies with `--fuzz=0`), Flameshot 12.1, Crow 2.11.1, Stow 2.3.1.
  The patch became version-agnostic (`clipboard-indicator.patch`, applied only if it fits
  exactly), and `focus-allowlist` declares GNOME 46–50.
  *Rejected:* keeping one patch per extension version (more to maintain, and the same diff fits both).
- **Clipboard: keep the picked item on the clipboard after pasting** (patch fix 2). Upstream
  restores the previous item after 50 ms, and asynchronous readers pasted the wrong item.
  *Rejected:* a longer restore delay. It's still a race, just a rarer one.
- **Monitor brightness/color control over DDC (`ddcutil`): tried, then removed** at the
  user's request. No measured calibration values exist for either monitor.

## 2026-11-19

- **Package cleanup**: see [packages.md](packages.md#cleanup-history-2026-11-19). Kept
  LibreOffice 24.8 and the build libraries on purpose; never purge the MySQL server's leftover config.
- **Grow the repo into a full OS setup with GNU Stow.**
  *Why Stow:* plain symlinks, standard and readable, matching the "edit in place" workflow.
  *Rejected:* chezmoi (copies plus templates: more power, but a different workflow);
  extending the custom `install.sh` link list (doesn't scale).
- **Curated dconf export, not a full `dconf dump /`**: a full dump includes network
  credentials, recent folders, accounts and window state. File names use `+` for `/`.
- **Public repo, secrets scrubbed by `snapshot.sh` with a failing guard.**
- **Flash on `Ctrl+V` / selection in Claude Code → `wl-copy`/`wl-paste` wrappers using xclip.**
  *Rejected:* uninstalling `wl-clipboard` (other tools use `wl-copy`); a wrapper that only
  covers Claude Code (the flash affects every caller of these exact shapes).
- **Clipboard Indicator stopped recording → 1 s timeout per format** (patch fix 3). Found
  while testing; the history file hadn't changed since an `xclip` image test.
- **Crow behind other windows → `focus-allowlist@local` with a D-Bus `Activate` method.**
  v1 reacted to "demands attention" and didn't work: Crow never emitted it in a way that let
  the window be raised. v2 had Crow's script ask the Shell directly. Raising twice caused a
  flash, so it now raises once, retrying only until the window exists.
  *Rejected:* NoAnnoyance / Steal My Focus Window (global; every app could take focus).
- **Crow copies via xclip** (no `wl-copy` flash); a 0.2 s wait lets mutter bridge the
  primary selection.
- **Image paste into Claude Code**: install `wl-clipboard` (Claude Code reads images with
  `wl-paste`). Clipboard Indicator sends `Ctrl+V` for image entries (patch fix 1).
- **Flameshot under XWayland**: the shortcut uses `QT_QPA_PLATFORM=xcb` (overlay spans both
  monitors, verified 7520×3840), and a **D-Bus service override** does the same for the
  auto-started daemon, because native Wayland Flameshot can't set the clipboard on GNOME.
- **Replace CopyQ with Clipboard Indicator.** CopyQ runs under XWayland on GNOME Wayland: its
  menu didn't get keyboard focus, and it can't paste into Wayland apps without `ydotool`.
  An intermediate fix (main window via `copyq toggle`, plus ydotool paste) worked, but
  needed `/dev/uinput` access. A Shell extension has neither problem.
  *Rejected:* GPaste (no GNOME 50 build), Pano (history of breaking on GNOME updates),
  Clipboard History (no open-at-pointer), logging in to an Xorg session.
  CopyQ was then fully removed (package, config, history, logs, autostart).
- **ydotool installed, then removed** (security: see [security.md](security.md#rejected-for-security-reasons)).
