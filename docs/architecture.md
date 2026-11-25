# Architecture

The repo holds four kinds of state, and each is applied differently. Which kind a file is
decides where it lives and how changes flow back into git.

```
                 ┌──────────────── ~/dotfiles (git) ────────────────┐
                 │                                                  │
  live machine   │  stow/<group>/…   ◄── symlinks ──  ~/.zshrc, ~/.config/Code/User/…
  (your $HOME)   │  configs/…        ── copied if absent ─►  ~/.config/flameshot, crow-translate
                 │  gnome/dconf/*.ini ── dconf load ─►  GNOME settings database
                 │  gnome/patches/*   ── patch ─►  third-party extension code
                 │  packages/*.txt    ── restore.sh ─►  apt / flatpak / snap / VS Code
                 └──────────────────────────────────────────────────┘
       edits flow back:  stow/ = automatic (same file) · everything else = ./snapshot.sh
```

## 1. Symlinked files: `stow/`

Each folder in `stow/` is a GNU Stow *package* that mirrors `$HOME`:

| Package | Files |
|---|---|
| `zsh` | `.zshrc`, `.zshenv`, `.bashrc`, `.profile` |
| `git` | `.gitconfig` |
| `vscode` | `.config/Code/User/settings.json`, `keybindings.json`, `mcp.json`, `snippets/` |
| `zed` | `.config/zed/settings.json` |
| `warp` | `.config/warp-terminal/settings.toml` |
| `desktop` | `.local/bin/{crow-wayland,wl-copy,wl-paste}`, the `focus-allowlist@local` Shell extension, the Flameshot D-Bus override |

`install.sh` runs `stow --no-folding --restow -d stow -t ~ <package>` for each package.

- **`--no-folding`**: Stow normally links a whole directory when it can ("folding"). Then
  any file an app creates inside it (for example VS Code's `globalStorage/`) would land in
  the repo. With `--no-folding`, only individual files are linked, and directories stay real.
- **Relative links**: Stow writes relative links (`../../dotfiles/stow/…`), so they survive
  a renamed home folder as long as `~/dotfiles` stays at the same relative place.
- **Conflicts**: before stowing, `install.sh` moves any real file or foreign symlink in the
  way to `<file>.pre-dotfiles`. Nothing is overwritten.

Editing a stowed file *is* editing the repo; just commit.

## 2. Copied configs: `configs/`

Flameshot (`flameshot.ini`) and Crow Translate (`crow-translate.conf`) rewrite their own
config files, often by replacing them, which would break a symlink. They are therefore
**copied once if absent** and refreshed into the repo by `snapshot.sh`.

`snapshot.sh` scrubs the Crow config: `LibreTranslateApiKey`, proxy host/user/password,
window geometry and `LanguagesPath` are emptied. Crow's autostart entry is stored as a
template (`io.crow_translate.CrowTranslate.desktop.in`), with `@HOME@` replaced at install time.

## 3. GNOME settings: `gnome/dconf/`

GNOME keeps settings in the dconf database, not in files. `snapshot.sh` dumps a **curated
list** of dconf paths (`DCONF_PATHS` in the script), one `.ini` per path:

- **File naming**: `/` in the dconf path becomes `+` in the file name
  (`desktop+input-sources.ini` → `/org/gnome/desktop/input-sources/`). `-` was not usable
  because dconf names contain dashes.
- **Home paths** are written as `@HOME@` (for example in the Crow shortcut commands) and
  replaced with the real home folder by `install.sh`.
- **State is filtered out**: keys like `last-*`, `welcome-dialog-last-shown-version` and
  `last-save-directory` are dropped.
- **Never exported**: network credentials (`nm-applet`), file-chooser history
  (`portal/filechooser`), Evolution/GOA accounts, location, remote desktop, window state.

`install.sh` loads each file with `dconf load`. That merges: keys that aren't in the file are
left alone.

What's covered: theme and fonts, window manager and mutter keybindings, input sources,
touchpad and keyboard, app folders, per-app notification rules, privacy, screensaver,
session, search providers, date/time, background, **custom shortcuts and power/colour**
(`settings-daemon+plugins.ini`), **GNOME Shell including every extension's settings**
(`shell.ini`), mutter, Nautilus, Ptyxis, gnome-terminal, Text Editor, gedit, Pomodoro.

## 4. Extensions and patches: `gnome/extensions.txt`, `gnome/patches/`

- `extensions.txt` lists extensions from extensions.gnome.org. `install.sh` asks GNOME Shell
  to install each missing one (`InstallRemoteExtension`). GNOME shows an approval prompt;
  re-run `install.sh` after accepting.
- Local extensions (`*@local`) are not listed: they live in `stow/desktop`.
- `patches/<extension>.patch` carries local fixes to a third-party extension (today only
  Clipboard Indicator; see [wayland-fixes.md](wayland-fixes.md)). It is **version-agnostic**:
  `install.sh` dry-runs it with `--fuzz=0` and applies it only if it fits exactly, saving the
  original as `extension.js.orig`. It's verified on v71 (GNOME 46) and v74 (GNOME 50).
  A marker comment `LOCAL PATCH` makes re-runs idempotent.

## 5. Packages: `packages/`

`apt.txt` (`apt-mark showmanual`), `flatpak.txt`, `snap.txt`, `vscode-extensions.txt`.
`restore.sh` installs what's missing and skips names the running release doesn't have. It is
**opt-in** (`install.sh --packages`), because it uses sudo. See [packages.md](packages.md).

## What is deliberately not here

Secrets, keys, histories, browser profiles, account data, app state, work tools: see
[security.md](security.md). Oh-my-zsh and its three plugins are **cloned** by `install.sh`,
not vendored.

## Supported systems

Ubuntu 26.04 (GNOME 50, daily driver) and Ubuntu 24.04 (GNOME 46). Version differences are
listed in the [README](../README.md#supported).
