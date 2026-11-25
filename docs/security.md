# Security

This repo is **public**. Everything in it is visible to anyone.

## Never committed

| What | Why / where it stays |
|---|---|
| SSH and GPG keys (`~/.ssh`, `~/.gnupg`) | Credentials |
| `~/.kube`, `~/.docker` | Cluster and registry credentials |
| Shell history | Contains commands, hosts, sometimes secrets |
| Browser profiles | Sessions, saved passwords |
| GNOME online accounts, Evolution data | Account tokens |
| dconf `nm-applet` | **Wi-Fi enterprise (EAP) credentials** |
| dconf `portal/filechooser` | Recent folders (reveals work paths) |
| dconf location and remote-desktop settings | Private |
| Clipboard Indicator history (`~/.cache/clipboard-indicator@tudmotu.com/`) | Anything you ever copied |
| Editor state (`workspaceStorage`, `globalStorage`), Warp `user_preferences.json` | App state, not settings |
| OCR language data (`*.traineddata`) | Large, downloadable |
| Work tools and work configs | Not personal |

`.gitignore` blocks `*.pre-dotfiles`, `*.orig`, `*.bak` and `*.traineddata`.

## Scrubbing and guards

- `snapshot.sh` empties Crow's `LibreTranslateApiKey`, proxy host/user/password, window
  geometry and `LanguagesPath` in the copied config.
- Home paths in dconf exports become `@HOME@`.
- `snapshot.sh` **fails** if a generated copy still contains your home path, `ApiKey=…`,
  `Password=…` or `token=`.
- `stow/vscode/.config/Code/User/mcp.json` holds no secret: the Context7 key is a
  `${input:CONTEXT7_API_KEY}` prompt, which VS Code stores in its own secret storage.
- The git identity uses GitHub's `noreply` address.

**Before every commit:** read `git diff`. Before adding a new file, search it for tokens,
passwords, internal hosts and IPs, emails, and work references.

## Tradeoffs accepted

### Screenshot permission

GNOME's screenshot portal remembers "Allow" for apps that aren't sandboxed (the permission is
stored for app id `""`). After the first Allow, **any non-Flatpak/Snap app can take
screenshots without asking**. This was accepted so Flameshot and Crow's OCR work without a
prompt each time. To revoke it:

```sh
gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
  --object-path /org/freedesktop/impl/portal/PermissionStore \
  --method org.freedesktop.impl.portal.PermissionStore.DeletePermission screenshot screenshot ''
```

### Clipboard history

Clipboard Indicator stores history **unencrypted** on disk. Delete sensitive entries
(highlight + `Delete` in the menu), or use the extension's private mode while copying secrets.

### Focus allowlist

`focus-allowlist@local` lets only listed apps (Crow) raise their windows over others. Keep
the list short: every entry weakens GNOME's protection against windows grabbing focus.

## Rejected for security reasons

- **ydotool** (for auto-paste with CopyQ). It needs `/dev/uinput` access through the `input`
  group, which lets any process running as you **inject keystrokes and read raw keyboard
  input**, so it could act as a keylogger. It was installed briefly, then fully removed (package, udev
  rule, group membership) once Clipboard Indicator made it unnecessary.
- **Global "steal my focus" extensions** (NoAnnoyance, Steal My Focus Window). They let
  *every* app take focus. Replaced by the allowlist above.

## Apps without an apt repository

Some apps installed from vendor `.deb` files (VS Code, Zoom, Discord, RustDesk, cloudflared,
Warp, Mockoon, Beekeeper Studio, OpenCode, Terminator) **don't get updates from
`apt upgrade`**. RustDesk (remote access) and cloudflared (tunnels) matter most. Keep them
current by hand, or add the vendor's apt repository where one exists. See
[packages.md](packages.md#apps-without-an-apt-repository).
