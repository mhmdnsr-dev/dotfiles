#!/usr/bin/env bash
# Apply GNOME settings: custom shortcuts, Clipboard Indicator options, display scaling.
# Safe to re-run. Custom shortcuts are keyed by fixed ids, so re-running updates them in place.
set -euo pipefail

MK=org.gnome.settings-daemon.plugins.media-keys
KB_BASE=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

# id | name | binding | command   (@BIN@ -> ~/.local/bin)
SHORTCUTS=(
  "custom0|emoji picker|<Primary>i|flatpak run it.mijorus.smile"
  "crow1|Crow: Translate selected text|<Primary><Alt>e|@BIN@/crow-wayland translate"
  "crow2|Crow: Speak selected text|<Primary><Alt>s|@BIN@/crow-wayland speak"
  "crow3|Crow: Speak translation of selected text|<Primary><Alt>f|@BIN@/crow-wayland speak-translation"
  "crow4|Crow: Stop text speaking|<Primary><Alt>g|@BIN@/crow-wayland stop"
  "crow5|Crow: Show main window|<Primary><Alt>c|@BIN@/crow-wayland show"
  "crow6|Crow: Recognize text in screen area|<Primary><Alt>i|@BIN@/crow-wayland ocr-recognize"
  "crow7|Crow: Translate text in screen area|<Primary><Alt>o|@BIN@/crow-wayland ocr-translate"
  "flameshot1|Flameshot: capture area|<Primary><Shift>Print|env QT_QPA_PLATFORM=xcb flameshot gui"
)

paths=$(gsettings get $MK custom-keybindings)
for s in "${SHORTCUTS[@]}"; do
  IFS='|' read -r id name binding cmd <<<"$s"
  p="$KB_BASE/$id/"
  case "$paths" in *"'$p'"*) ;; *)
    if [ "$paths" = "@as []" ] || [ "$paths" = "[]" ]; then paths="['$p']"; else paths="${paths%]}, '$p']"; fi ;;
  esac
  gsettings set "$MK.custom-keybinding:$p" name "$name"
  gsettings set "$MK.custom-keybinding:$p" binding "$binding"
  gsettings set "$MK.custom-keybinding:$p" command "${cmd//@BIN@/$HOME/.local/bin}"
done
gsettings set $MK custom-keybindings "$paths"
echo "shortcuts: ${#SHORTCUTS[@]} applied"

# Clipboard Indicator (only if installed): Ctrl+Alt+V, open at pointer, paste on select.
CI=$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/schemas
if [ -d "$CI" ]; then
  ci() { gsettings --schemadir "$CI" set org.gnome.shell.extensions.clipboard-indicator "$@"; }
  ci enable-keybindings true
  ci toggle-menu "['<Primary><Alt>v']"
  ci open-at-cursor true
  ci paste-on-select true
  ci show-search-bar true
  echo "clipboard-indicator: settings applied"
fi

# Fractional scaling + crisp XWayland apps (Flameshot runs under XWayland).
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer', 'xwayland-native-scaling']"
echo "mutter: fractional scaling + xwayland-native-scaling on"
