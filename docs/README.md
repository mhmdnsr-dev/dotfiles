# Documentation

| I want to… | Read |
|---|---|
| Understand how this repo is put together and why | [architecture.md](architecture.md) |
| Set up a new machine (Ubuntu 24.04 or 26.04) | [new-machine.md](new-machine.md) |
| Change something, add a file or app, update after an extension upgrade | [maintenance.md](maintenance.md) |
| Know what each desktop fix does and how to undo it | [wayland-fixes.md](wayland-fixes.md) |
| Fix something that stopped working | [troubleshooting.md](troubleshooting.md) |
| Know what is never committed, and which tradeoffs were accepted | [security.md](security.md) |
| Reinstall or clean up packages | [packages.md](packages.md) |
| Know why something was done this way, or what was rejected | [decisions.md](decisions.md) |

## Quick reference

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+V` | Clipboard history at the mouse pointer: pick an item, and it pastes and closes |
| `Ctrl+Shift+Print` | Flameshot area capture across all monitors (`Ctrl+C` copies the image) |
| `Print` | GNOME screenshot UI |
| `Ctrl+Alt+E` / `S` / `F` / `G` | Crow: translate / speak / speak translation / stop |
| `Ctrl+Alt+C` | Crow main window, raised to the front |
| `Ctrl+Alt+I` / `O` | OCR a screen area: copy the text / translate it |
| `Ctrl+I` | Emoji picker (Smile) |

| Command | Does |
|---|---|
| `./install.sh [--packages]` | Apply everything (safe to re-run) |
| `./snapshot.sh && git diff` | Re-export the copied parts (GNOME settings, lists, configs, patch) |
| `./packages/restore.sh --dry-run` | Show which packages are missing |
| `stow -n --no-folding -d stow -t ~ $(ls stow)` | Link health check (no output = healthy) |
