# Setting up a new machine

Works on Ubuntu 26.04 (GNOME 50) and Ubuntu 24.04 (GNOME 46), on a GNOME **Wayland** session.
It takes about 15 minutes plus package downloads.

## 1. Prerequisites

```sh
sudo apt install git stow dconf-cli libglib2.0-bin python3 patch
git clone https://github.com/mhmdnsr-dev/dotfiles ~/dotfiles
cd ~/dotfiles
```

Keep the repo at `~/dotfiles`. The symlinks are relative and expect it there.

## 2. Packages (optional, uses sudo)

```sh
./packages/restore.sh --dry-run    # what's missing; names not in this release are listed as skipped
./install.sh --packages            # or install packages yourself and run ./install.sh
```

The desktop fixes need at least:

```sh
sudo apt install xclip wl-clipboard flameshot crow-translate tesseract-ocr python3-gi
```

Apps installed from vendor `.deb` files (VS Code, Zoom, Discord, RustDesk and others) are in
`apt.txt` but not in Ubuntu's repositories, so `restore.sh` skips them. Install them from the
vendor's site. See [packages.md](packages.md#apps-without-an-apt-repository).

## 3. Install

```sh
./install.sh
```

In order, it:
1. clones oh-my-zsh and its plugins (zsh-autosuggestions, zsh-syntax-highlighting, you-should-use);
2. stows every package in `stow/`, moving anything in the way to `*.pre-dotfiles`;
3. copies the Flameshot and Crow configs if absent, and writes Crow's autostart entry;
4. asks GNOME to install the extensions in `gnome/extensions.txt`. **Accept each prompt**;
5. applies `gnome/patches/*.patch` if the installed extension version fits;
6. loads `gnome/dconf/*.ini`: shortcuts, theme, extension settings, and the rest.

**Run it a second time** after accepting the extension prompts, so the patch and the
extension settings are applied to the newly installed extensions.

## 4. Log out and back in

On Wayland, GNOME Shell only loads new or changed extensions at login.

## 5. First-use prompts

- **First `Ctrl+Shift+Print`:** GNOME asks "Allow screenshot?". Click Allow; it's remembered
  (see [security.md](security.md#screenshot-permission)).
- **VS Code MCP (Context7):** VS Code prompts for the API key the first time; it's stored in
  VS Code's secret storage, never in the repo.
- **Crow OCR:** needs `tesseract-ocr` and its language data (`tesseract-ocr-ara` for Arabic).

## 6. Verify

| Check | Expected |
|---|---|
| `stow -n --no-folding -d stow -t ~ $(ls stow)` | no output |
| `gnome-extensions list --enabled` | includes `clipboard-indicator@tudmotu.com`, `focus-allowlist@local` |
| `grep -c 'LOCAL PATCH' ~/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/extension.js` | `3` |
| `Ctrl+Alt+V` in a text field | menu at the pointer; Enter pastes the chosen item |
| `Ctrl+Shift+Print` | overlay covers every monitor; `Ctrl+C` copies the image |
| Select text, `Ctrl+Alt+E` | Crow translates and comes to the front |
| `which wl-copy wl-paste` | `~/.local/bin/…` (the wrappers) |

## Ubuntu 24.04 specifics

- Clipboard Indicator installs as **v71**. The same patch applies.
- Flameshot is **12.1**. The XWayland D-Bus override works the same way.
- Settings that only exist on newer GNOME (such as `xwayland-native-scaling`) are written
  but ignored.
- Ptyxis isn't the default terminal, so its settings are unused.

## Rolling back

| Undo | How |
|---|---|
| A replaced file | `mv ~/<file>.pre-dotfiles ~/<file>` (after `stow -D` of its package) |
| All symlinks | `cd ~/dotfiles && stow -D -d stow -t ~ $(ls stow)` |
| The Clipboard Indicator patch | `mv extension.js.orig extension.js` in the extension folder, then log out and in |
| An extension | `gnome-extensions disable <uuid>` |
| GNOME settings | there is no automatic backup. `dconf dump / > ~/dconf-before.ini` before step 3 lets you restore with `dconf load / < ~/dconf-before.ini` |
