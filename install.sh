#!/usr/bin/env bash
# Install this desktop setup for the current user. Safe to re-run.
#   ./install.sh               # dotfiles, shell framework, GNOME settings + extensions
#   ./install.sh --packages    # also reinstall apt/flatpak/snap/VS Code packages (sudo)
#
# stow/<pkg>/  mirrors $HOME and is SYMLINKED with GNU Stow (edit in place, then commit).
# configs/     app configs the apps rewrite themselves: COPIED only if absent.
# gnome/       dconf settings (loaded), extension list (installed), local patches (applied).
# Files that would be replaced are kept as *.pre-dotfiles.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd -P)
EXT_DIR=$HOME/.local/share/gnome-shell/extensions
say() { printf '\033[1m==> %s\033[0m\n' "$*"; }

for cmd in stow git dconf gdbus python3 patch; do
  command -v "$cmd" >/dev/null || { echo "missing '$cmd': sudo apt install stow git dconf-cli libglib2.0-bin python3 patch"; exit 1; }
done

if [ "${1:-}" = --packages ]; then
  say "Packages"
  bash "$REPO/packages/restore.sh"
fi

say "oh-my-zsh and plugins"
[ -d "$HOME/.oh-my-zsh" ] || git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
ZC=$HOME/.oh-my-zsh/custom
clone() { [ -d "$2" ] || { git clone -q --depth 1 "$1" "$2" && echo "   cloned $(basename "$2")"; }; }
clone https://github.com/zsh-users/zsh-autosuggestions        "$ZC/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting    "$ZC/plugins/zsh-syntax-highlighting"
clone https://github.com/MichaelAquilina/zsh-you-should-use   "$ZC/plugins/you-should-use"

say "Dotfiles (GNU Stow)"
for pkg in "$REPO"/stow/*/; do
  pkg=$(basename "$pkg")
  # Move files and foreign symlinks that are in the way aside, so stow can link.
  while IFS= read -r rel; do
    dst=$HOME/$rel
    if [ -L "$dst" ]; then
      case "$(readlink -f "$dst")" in "$REPO"/*) continue ;; esac   # already ours
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.pre-dotfiles"; echo "   kept old ~/$rel as .pre-dotfiles"; fi
  done < <(cd "$REPO/stow/$pkg" && find . -type f -o -type l | sed 's#^\./##')
  stow --no-folding --restow -d "$REPO/stow" -t "$HOME" "$pkg"
  echo "   $pkg"
done

say "App configs (copied if absent)"
copy_if_absent() {
  if [ -e "$2" ]; then echo "   exists, left as is: $2"; else mkdir -p "$(dirname "$2")"; cp "$REPO/$1" "$2"; echo "   copied $2"; fi
}
copy_if_absent configs/flameshot/flameshot.ini            "$HOME/.config/flameshot/flameshot.ini"
copy_if_absent configs/crow-translate/crow-translate.conf "$HOME/.config/crow-translate/crow-translate.conf"
mkdir -p "$HOME/.config/autostart"
sed "s#@HOME@#$HOME#g" "$REPO/configs/crow-translate/io.crow_translate.CrowTranslate.desktop.in" \
  > "$HOME/.config/autostart/io.crow_translate.CrowTranslate.desktop"

say "GNOME extensions"
while read -r uuid; do
  [ -z "$uuid" ] && continue
  if [ -d "$EXT_DIR/$uuid" ]; then echo "   installed: $uuid"; continue; fi
  echo "   installing $uuid (accept the GNOME prompt)"
  gdbus call --session --dest org.gnome.Shell.Extensions --object-path /org/gnome/Shell/Extensions \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$uuid" >/dev/null 2>&1 || true
done < "$REPO/gnome/extensions.txt"

# Local patches: gnome/patches/<extension-name>.patch. Versions differ per GNOME release
# (Ubuntu 24.04 gets Clipboard Indicator v71, 26.04 gets v74), so instead of pinning a version,
# apply only if the patch fits exactly (no fuzz); otherwise skip and say so.
for patch in "$REPO"/gnome/patches/*.patch; do
  [ -e "$patch" ] || continue
  ext=$(basename "$patch" .patch)
  dir=$(ls -d "$EXT_DIR/$ext@"* 2>/dev/null | head -1 || true)
  [ -n "$dir" ] && [ -f "$dir/extension.js" ] || { echo "   $ext not installed yet: re-run after accepting the prompt"; continue; }
  have=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$dir/metadata.json")
  if grep -q 'LOCAL PATCH' "$dir/extension.js"; then echo "   $ext v$have: already patched"
  elif patch --dry-run -s --fuzz=0 -d "$dir" -p1 < "$patch" >/dev/null 2>&1; then
    cp "$dir/extension.js" "$dir/extension.js.orig"; patch -s --fuzz=0 -d "$dir" -p1 < "$patch"; echo "   $ext v$have: patched"
  else echo "   $ext v$have: patch does not fit this version, skipped (re-port gnome/patches/$ext.patch)"; fi
done

say "GNOME settings (dconf)"
for ini in "$REPO"/gnome/dconf/*.ini; do
  name=$(basename "$ini" .ini)
  path=/org/gnome/${name//+//}/          # file names encode '/' as '+': desktop+wm.ini -> desktop/wm
  sed "s#@HOME@#$HOME#g" "$ini" | dconf load "$path"
  echo "   $path"
done

say "Done. Log out and back in so GNOME loads extensions and settings."
