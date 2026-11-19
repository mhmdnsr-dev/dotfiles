#!/usr/bin/env bash
# Install this GNOME Wayland desktop setup for the current user. Safe to re-run.
# - Scripts, the focus-allowlist extension and the Flameshot D-Bus override are SYMLINKED
#   to this repo (edit in place, then commit).
# - Flameshot and Crow configs are COPIED only if absent (those apps rewrite their files).
# - Existing files that would be replaced are kept as *.pre-dotfiles.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
EXT_DIR=$HOME/.local/share/gnome-shell/extensions
CI_UUID=clipboard-indicator@tudmotu.com
CI_VERSION=74

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }

link() { # link <repo-path> <target>
  local src=$REPO/$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then return; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.pre-dotfiles"; echo "   kept old $dst as .pre-dotfiles"; fi
  ln -s "$src" "$dst"; echo "   linked $dst"
}

copy_if_absent() { # copy_if_absent <repo-path> <target>
  local dst=$2
  if [ -e "$dst" ]; then echo "   exists, left as is: $dst"; return; fi
  mkdir -p "$(dirname "$dst")"; cp "$REPO/$1" "$dst"; echo "   copied $dst"
}

say "Checking packages"
missing=()
for pkg in xclip wl-clipboard flameshot crow-translate tesseract-ocr python3-gi; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "   missing: ${missing[*]}"
  echo "   install with: sudo apt install ${missing[*]}"
fi

say "Scripts -> ~/.local/bin"
for f in "$REPO"/bin/*; do link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"; done

say "Focus Allowlist extension (raises Crow when GNOME refuses its focus request)"
link gnome-shell/extensions/focus-allowlist@local "$EXT_DIR/focus-allowlist@local"

say "Flameshot (XWayland D-Bus override: spans all monitors, copy-to-clipboard works)"
link flameshot/org.flameshot.Flameshot.service "$HOME/.local/share/dbus-1/services/org.flameshot.Flameshot.service"
copy_if_absent flameshot/flameshot.ini "$HOME/.config/flameshot/flameshot.ini"

say "Crow Translate"
copy_if_absent crow-translate/crow-translate.conf "$HOME/.config/crow-translate/crow-translate.conf"
mkdir -p "$HOME/.config/autostart"
sed "s#@HOME@#$HOME#g" "$REPO/crow-translate/io.crow_translate.CrowTranslate.desktop.in" \
  > "$HOME/.config/autostart/io.crow_translate.CrowTranslate.desktop"
echo "   autostart entry written"

say "Clipboard Indicator v$CI_VERSION + local patch"
if [ ! -d "$EXT_DIR/$CI_UUID" ]; then
  echo "   installing from extensions.gnome.org (accept the GNOME prompt)"
  gdbus call --session --dest org.gnome.Shell.Extensions --object-path /org/gnome/Shell/Extensions \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$CI_UUID" >/dev/null 2>&1 || true
fi
if [ -f "$EXT_DIR/$CI_UUID/extension.js" ]; then
  ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$EXT_DIR/$CI_UUID/metadata.json")
  if grep -q 'LOCAL PATCH' "$EXT_DIR/$CI_UUID/extension.js"; then
    echo "   already patched"
  elif [ "$ver" = "$CI_VERSION" ]; then
    cp "$EXT_DIR/$CI_UUID/extension.js" "$EXT_DIR/$CI_UUID/extension.js.orig"
    patch -s -d "$EXT_DIR/$CI_UUID" -p1 < "$REPO/gnome-shell/patches/clipboard-indicator-v$CI_VERSION.patch"
    echo "   patched (original kept as extension.js.orig)"
  else
    echo "   installed version is v$ver, patch targets v$CI_VERSION: skipped, re-port the patch"
  fi
else
  echo "   not installed yet: re-run this script after accepting the install prompt"
fi

say "Enabling extensions"
enabled=$(gsettings get org.gnome.shell enabled-extensions)
for uuid in "$CI_UUID" focus-allowlist@local; do
  case "$enabled" in *"'$uuid'"*) ;; *)
    if [ "$enabled" = "@as []" ] || [ "$enabled" = "[]" ]; then enabled="['$uuid']"; else enabled="${enabled%]}, '$uuid']"; fi ;;
  esac
done
gsettings set org.gnome.shell enabled-extensions "$enabled"

say "GNOME settings"
bash "$REPO/gnome/settings.sh"

say "Done. Log out and back in so GNOME loads the extensions."
