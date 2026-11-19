#!/usr/bin/env bash
# Refresh the COPIED parts of this repo from the live machine (symlinked files need nothing).
# Crow's config is scrubbed: API key, proxy credentials, window geometry and home paths are cleared.
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)

cp "$HOME/.config/flameshot/flameshot.ini" "$REPO/flameshot/flameshot.ini"

python3 -I - "$HOME/.config/crow-translate/crow-translate.conf" "$REPO/crow-translate/crow-translate.conf" <<'PY'
import sys
src, dst = sys.argv[1:3]
SCRUB = {"LibreTranslateApiKey", "WindowGeometry", "LanguagesPath", "ProxyHost", "ProxyUsername", "ProxyPassword"}
out = []
for line in open(src, encoding="utf-8"):
    key = line.split("=", 1)[0].strip()
    out.append(f"{key}=\n" if "=" in line and key in SCRUB else line)
open(dst, "w", encoding="utf-8").write("".join(out))
PY

E=$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
if [ -f "$E/extension.js.orig" ]; then
  ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$E/metadata.json")
  diff -u --label a/extension.js --label b/extension.js "$E/extension.js.orig" "$E/extension.js" \
    > "$REPO/gnome-shell/patches/clipboard-indicator-v$ver.patch" || true
fi

# Refuse to leave anything that looks like a home path or secret in the copies.
if grep -rnE "$HOME|ApiKey=.+|Password=.+" "$REPO/flameshot" "$REPO/crow-translate" --exclude='*.in'; then
  echo "!! review the lines above before committing" >&2; exit 1
fi
echo "snapshot updated; review with: git -C $REPO diff"
