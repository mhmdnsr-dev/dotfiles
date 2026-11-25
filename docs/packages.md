# Packages

## Lists

| File | Source | Restored by |
|---|---|---|
| `packages/apt.txt` | `apt-mark showmanual` | `restore.sh` (installs missing; skips names this release doesn't have) |
| `packages/flatpak.txt` | `flatpak list --app` | `restore.sh` (from Flathub) |
| `packages/snap.txt` | `/snap` contents minus bases/runtimes (`snap list` hangs on this machine) | `restore.sh` |
| `packages/vscode-extensions.txt` | `code --list-extensions` | `restore.sh` |

```sh
./packages/restore.sh --dry-run   # show what's missing
./packages/restore.sh             # install it (sudo)
```

`apt.txt` includes packages that came with the Ubuntu install, because they are also marked
manual. That's harmless: installed ones are skipped.

## Apps without an apt repository

These were installed from vendor `.deb` files, so they appear in `apt.txt` but
`restore.sh` can't fetch them, and `apt upgrade` never updates them:

| App | Get it from | Note |
|---|---|---|
| VS Code | code.visualstudio.com, or Microsoft's apt repo | Adding the repo enables updates |
| Zoom | zoom.us | |
| Discord | discord.com | Prompts for updates itself |
| RustDesk | github.com/rustdesk/rustdesk releases | **Remote access: keep it current** |
| cloudflared | Cloudflare's apt repo (`pkg.cloudflare.com`) | **Tunnels: keep it current** |
| Warp | Warp's apt repo (present but disabled in `sources.list.d`) | |
| Mockoon, Beekeeper Studio, OpenCode, Terminator | vendor sites | |

## Cleanup history (2026-11-19)

The goal was to cut the package list down to what's used. "Unused" was judged from GNOME's
app usage record (`~/.local/share/gnome-shell/application_state`), which only covers recently
opened apps.

**Removed**
- Apps: Claude Desktop, Microsoft Edge, TickTick, Kazam, Cursor, with their apt repo files
  and their data in `~/.config` (about 3.8 GB).
- Leftovers from Ubuntu 24.04: the 6.8 kernel, `libpython3.12*`, `libicu74`, `mysql-apt-config`.
- Leftover config of already-removed packages: `ydotool`, `kwayland-data`, `keyboxd`,
  `dotnet-host-8.0`, `desktop-icons-ng`.
- `autoremove` cascade: the official GNOME extensions bundle (none were enabled),
  GNOME Classic, Kazam's Python libraries, `uidmap` and `virtiofsd`. These are only needed for
  rootless Docker/Podman and libvirt shared folders; Docker here runs rootful, and there are
  no VMs.
- VS Code extensions (74 → 59): duplicates (`oracle.oracle-java`, `vscode-docker`, `githistory`,
  `vscode-latex`, `auto-close-tag`, `auto-rename-tag`, `cpptools-themes`), the C/C++ set,
  and Marko, HTMX, React Native and Vue support.

**Marked automatic, not removed:** about 14 libraries that were wrongly marked manual. apt
keeps them while something depends on them.

**Kept on purpose**
- **LibreOffice 24.8** alongside the distro's 26.2.
- All `-dev` build libraries, `cmake`, `swig`, `libtool` (for native module builds).
- Azure CLI (needed by work tooling).
- **Never purge the leftover config of `mysql-community-server`.** Purging it can delete the
  local MySQL data directory (`/var/lib/mysql`).

Result: 266 → 243 manual apt packages, 65 → 69 GB free.

**Still candidates** (unused-looking, not removed yet): Beekeeper Studio, Mockoon, the
OpenCode desktop app, Sublime Text, Pinta, Terminator, Warp.
