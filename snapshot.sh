#!/usr/bin/env bash
# Refresh the COPIED parts of this repo from the live machine. Stow-managed files are
# symlinks into stow/ and need nothing. Review with `git diff` before committing.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)

# ---- GNOME settings (dconf): curated paths only. Never: nm-applet (network creds),
# portal/filechooser (recent folders), evolution, goa, location, remote-desktop, window state.
DCONF_PATHS=(
  desktop/interface desktop/wm desktop/peripherals desktop/input-sources desktop/app-folders
  desktop/notifications desktop/privacy desktop/screensaver desktop/session
  desktop/search-providers desktop/datetime desktop/background
  settings-daemon/plugins shell mutter nautilus/preferences Ptyxis terminal/legacy
  TextEditor gedit/preferences pomodoro/preferences
)
mkdir -p "$REPO/gnome/dconf"
rm -f "$REPO"/gnome/dconf/*.ini
for p in "${DCONF_PATHS[@]}"; do
  out="$REPO/gnome/dconf/${p//\//+}.ini"   # '/' -> '+' (dconf names may contain '-')
  dconf dump "/org/gnome/$p/" \
    | grep -vE '^(last-[a-z-]+|welcome-dialog-last-shown-version|last-save-directory)=' \
    | sed "s#$HOME#@HOME@#g" > "$out"
  [ -s "$out" ] || rm -f "$out"
done

# ---- Extensions installed by the user (from extensions.gnome.org), except local ones in stow/.
gnome-extensions list --user | grep -v '@local$' | sort > "$REPO/gnome/extensions.txt"

# ---- Package lists.
mkdir -p "$REPO/packages"
apt-mark showmanual | sort > "$REPO/packages/apt.txt"
command -v flatpak >/dev/null && flatpak list --app --columns=application | sort > "$REPO/packages/flatpak.txt" || true
# `snap list` can hang on this machine; read installed snaps from /snap instead, skipping bases/runtimes.
ls /snap 2>/dev/null | grep -vE '^(bin|README|snapd|bare|core[0-9]*|gnome-[0-9-]+|gtk-common-themes|mesa-[0-9a-z-]+|kf[0-9]-.*|snapd-desktop-integration)$' \
  | sort > "$REPO/packages/snap.txt" || true
command -v code >/dev/null && code --list-extensions 2>/dev/null | sort > "$REPO/packages/vscode-extensions.txt" || true

# ---- App configs those apps rewrite themselves (copied, not stowed).
cp "$HOME/.config/flameshot/flameshot.ini" "$REPO/configs/flameshot/flameshot.ini"
python3 -I - "$HOME/.config/crow-translate/crow-translate.conf" "$REPO/configs/crow-translate/crow-translate.conf" <<'PY'
import sys
src, dst = sys.argv[1:3]
SCRUB = {"LibreTranslateApiKey", "WindowGeometry", "LanguagesPath", "ProxyHost", "ProxyUsername", "ProxyPassword"}
out = []
for line in open(src, encoding="utf-8"):
    key = line.split("=", 1)[0].strip()
    out.append(f"{key}=\n" if "=" in line and key in SCRUB else line)
open(dst, "w", encoding="utf-8").write("".join(out))
PY

# ---- Clipboard Indicator local patch.
E=$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
if [ -f "$E/extension.js.orig" ]; then
  ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$E/metadata.json")
  diff -u --label a/extension.js --label b/extension.js "$E/extension.js.orig" "$E/extension.js" \
    > "$REPO/gnome/patches/clipboard-indicator-v$ver.patch" || true
fi

# ---- Guard: nothing secret-looking or home-path-bearing in the generated copies.
if grep -rnE "$HOME|ApiKey=.+|Password=.+|password'|token=" "$REPO/gnome/dconf" "$REPO/configs"; then
  echo "!! review the lines above before committing" >&2; exit 1
fi
echo "snapshot updated; review with: git -C $REPO diff --stat"
