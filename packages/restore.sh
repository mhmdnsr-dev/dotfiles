#!/usr/bin/env bash
# Reinstall packages from the lists in this folder. Opt-in: run it yourself, it uses sudo.
#   ./packages/restore.sh            # apt + flatpak + snap + VS Code extensions
#   ./packages/restore.sh --dry-run  # only show what is missing
# apt.txt is `apt-mark showmanual` from my machine: packages unknown to this release are skipped.
set -uo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
DRY=${1:-}

list() { [ -s "$DIR/$1" ] && grep -vE '^\s*(#|$)' "$DIR/$1"; }

echo "==> apt"
missing=()
while read -r p; do
  dpkg -s "$p" >/dev/null 2>&1 && continue
  apt-cache show "$p" >/dev/null 2>&1 && missing+=("$p") || echo "   not available here, skipped: $p"
done < <(list apt.txt)
echo "   missing: ${#missing[@]}"
if [ ${#missing[@]} -gt 0 ]; then
  if [ "$DRY" = --dry-run ]; then printf '   %s\n' "${missing[@]}"; else sudo apt-get install -y "${missing[@]}"; fi
fi

if command -v flatpak >/dev/null; then
  echo "==> flatpak"
  while read -r app; do
    flatpak info "$app" >/dev/null 2>&1 && continue
    if [ "$DRY" = --dry-run ]; then echo "   missing: $app"; else flatpak install -y flathub "$app"; fi
  done < <(list flatpak.txt)
fi

if command -v snap >/dev/null; then
  echo "==> snap"
  while read -r s; do
    [ -d "/snap/$s" ] && continue
    if [ "$DRY" = --dry-run ]; then echo "   missing: $s"; else sudo snap install "$s"; fi
  done < <(list snap.txt)
fi

if command -v code >/dev/null; then
  echo "==> VS Code extensions"
  installed=$(code --list-extensions 2>/dev/null)
  while read -r ext; do
    grep -qix "$ext" <<<"$installed" && continue
    if [ "$DRY" = --dry-run ]; then echo "   missing: $ext"; else code --install-extension "$ext" >/dev/null && echo "   installed $ext"; fi
  done < <(list vscode-extensions.txt)
fi
