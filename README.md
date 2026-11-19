# dotfiles

My Ubuntu 26.04 / GNOME 50 (Wayland) setup: shell, editors, terminal, GNOME settings and
extensions, packages, and a set of fixes that make clipboard, screenshot and translation
tools behave on Wayland.

## Install on a new machine

```sh
sudo apt install git stow dconf-cli
git clone https://github.com/mhmdnsr-dev/dotfiles ~/dotfiles
cd ~/dotfiles
./packages/restore.sh --dry-run   # see what would be installed
./install.sh --packages           # or ./install.sh to skip packages
# accept the GNOME prompts for extensions, re-run ./install.sh once, then log out and in
```

`install.sh` is safe to re-run. Any real file it would replace is kept as `*.pre-dotfiles`.

## Layout

| Path | What | How it's applied |
|---|---|---|
| `stow/zsh` | `.zshrc`, `.zshenv`, `.p10k.zsh`, `.bashrc`, `.profile` | symlinked (GNU Stow) |
| `stow/git` | `.gitconfig` | symlinked |
| `stow/vscode`, `stow/zed` | editor settings, keybindings, snippets, VS Code MCP servers | symlinked |
| `stow/warp` | Warp terminal `settings.toml` | symlinked |
| `stow/desktop` | Wayland helper scripts, the `focus-allowlist` Shell extension, the Flameshot D-Bus override | symlinked |
| `configs/` | Flameshot and Crow Translate configs | copied if absent (these apps rewrite their files) |
| `gnome/dconf/` | selected GNOME settings: theme, shortcuts, mutter, Nautilus, notifications, app folders, extension settings, Ptyxis… | `dconf load` |
| `gnome/extensions.txt` | extensions from extensions.gnome.org | installed via GNOME's prompt |
| `gnome/patches/` | local fixes for third-party extensions | applied when the version matches |
| `packages/` | apt, Flatpak, snap and VS Code extension lists | `packages/restore.sh` (opt-in) |

Oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting, you-should-use and powerlevel10k are
cloned by `install.sh`, not vendored.

## Keeping it current

- **Symlinked files** (`stow/`): edit them where they are; the change is already in the repo. Commit.
- **Everything else**: `./snapshot.sh && git diff`. This re-exports GNOME settings, extension
  and package lists, app configs and extension patches. It scrubs secrets and home paths
  (stored as `@HOME@`), and refuses to finish if anything secret-looking remains.
- **New file to track**: move it into `stow/<group>/` at the same relative path, then run
  `stow --no-folding -d stow -t ~ <group>`.

## Never in this repo

SSH/GPG keys, `.kube`, `.docker`, shell history, browser profiles, online accounts, network
settings (`nm-applet` holds Wi-Fi enterprise credentials), file-chooser history, clipboard
history, editor workspace state, and anything work-related.

## Wayland fixes (why `stow/desktop` exists)

GNOME on Wayland blocks focus stealing, synthetic key presses and windows spanning monitors,
and it lacks the *data-control* protocol that clipboard CLIs use.

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+V` | Clipboard history at the mouse pointer; pick an item and it pastes (text **or image**) and closes |
| `Ctrl+Shift+Print` | Flameshot across **all monitors**; `Ctrl+C` copies the image |
| `Ctrl+Alt+E` / `S` / `F` / `G` | Crow: translate / speak / speak translation / stop |
| `Ctrl+Alt+C` | Crow main window, raised to the front |
| `Ctrl+Alt+I` / `O` | OCR a screen area: copy the text / translate it |
| `Ctrl+I` | Emoji picker (Smile) |

- **[Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator/)**
  runs inside GNOME Shell, so it can open at the pointer and paste without `ydotool`.
  [`gnome/patches/`](gnome/patches/) adds two fixes:
  1. **Image paste:** for images, send `Ctrl+V` and keep the image on the clipboard.
     Upstream uses text-only `Shift+Insert` and restores the old item after 50 ms.
  2. **Hang guard:** a 1 s timeout per clipboard-format request. An XWayland owner that
     never answers otherwise stops all recording, without any error.
- **`wl-copy` / `wl-paste` wrappers:** without data-control, the real tools briefly map a
  window (a flash at the screen edge). The wrappers route the simple calls Claude Code makes
  through `xclip` via XWayland; everything else falls through to the real binaries.
- **Flameshot D-Bus override:** runs the daemon under XWayland, so the capture overlay
  spans monitors and `Ctrl+C` reaches the clipboard.
- **`crow-wayland` + `focus-allowlist@local`:** bridges shortcuts to Crow's D-Bus API (OCR
  via the screenshot portal and tesseract). A tiny Shell extension raises Crow's window, which
  GNOME otherwise refuses because the request carries no activation token. It applies to
  allow-listed apps only.

## Caveats

- Extension updates overwrite local patches. `install.sh` says so; re-port the patch.
- If an app saves settings by replacing the file, its symlink becomes a real file again.
  Check occasionally with `cd ~/dotfiles && stow -n --no-folding -d stow -t ~ $(ls stow)`.
  It prints nothing when every link is intact and names any file that has been replaced. Copy
  that file's content into `stow/`, delete it, and re-run the stow command without `-n`.
- `gnome/dconf` replays my settings as they are, including app folder IDs and favourite
  apps that may reference apps you don't have. GNOME ignores entries it can't use.
