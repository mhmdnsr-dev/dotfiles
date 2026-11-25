# Maintenance

## Everyday changes

| You changed… | Then |
|---|---|
| A stowed file (`.zshrc`, VS Code settings, a script in `stow/desktop`) | It's already the repo file: `git commit` |
| GNOME settings, a shortcut, an extension's settings | `./snapshot.sh && git diff`, then commit |
| Installed or removed a package or VS Code extension | `./snapshot.sh && git diff`, then commit |
| Flameshot or Crow settings | `./snapshot.sh && git diff`, then commit |

`snapshot.sh` refuses to finish if the generated copies contain a home path or something
secret-looking. Read the lines it prints, fix them, and run it again.

**Always read `git diff` before committing.** The repo is public.

## Track a new config file

```sh
cd ~/dotfiles
mkdir -p stow/<group>/<path-relative-to-home>
mv ~/<path>/<file> stow/<group>/<path>/<file>
stow --no-folding -d stow -t ~ <group>
git add stow/<group> && git commit
```

Use a new group for a new app (`stow/kitty`, …) or add to an existing one. Before adding,
check the file for tokens, passwords, internal hostnames and work paths. If the app replaces
its config file on save, don't stow it: add it under `configs/` with a scrubbing step in
`snapshot.sh`, like Crow.

## Stop tracking a file

```sh
cd ~/dotfiles
stow -D --no-folding -d stow -t ~ <group>     # removes the links of that group
cp stow/<group>/<path>/<file> ~/<path>/<file>  # if you want to keep it locally
git rm stow/<group>/<path>/<file>
stow --no-folding -d stow -t ~ <group>         # re-link what's left of the group
```

## Track another GNOME setting

Add its path (relative to `/org/gnome/`) to `DCONF_PATHS` in `snapshot.sh`, then run
`./snapshot.sh` and read the new `.ini` for anything private before committing. Settings
outside `/org/gnome/` aren't covered by the loop; extend the script if you need them.

## Link health

```sh
cd ~/dotfiles && stow -n --no-folding -d stow -t ~ $(ls stow)
```

No output means every link is intact. A conflict line names a file that an app replaced with
a real file. To repair it: copy the file's content into `stow/`, delete the real file, and
re-run the command without `-n`. Zed and Warp haven't been confirmed to save through links,
so check after changing their settings.

## After a Clipboard Indicator update

An extension update replaces `extension.js` and drops the local fixes.

1. Re-run `./install.sh`. If the patch still fits exactly, it's re-applied (`…: patched`).
2. If it says `patch does not fit this version, skipped`, re-port it:
   ```sh
   E=~/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
   cp $E/extension.js $E/extension.js.orig
   # re-apply the three LOCAL PATCH changes by hand (see wayland-fixes.md and the old patch)
   ./snapshot.sh        # regenerates gnome/patches/clipboard-indicator.patch from .orig vs current
   ```
3. Log out and back in, run the verification table in [new-machine.md](new-machine.md#6-verify),
   and commit.

## After a GNOME upgrade (new Ubuntu release)

- `focus-allowlist@local/metadata.json` lists the supported `shell-version`s. Add the new
  number once you've checked the extension still loads (`gnome-extensions info focus-allowlist@local`).
- Check that the patch still applies, as above.
- Run `./snapshot.sh`: new default settings may show up in the diff.

## Updating the docs

When you change behaviour, update the matching page in `docs/` and add a dated line to
[decisions.md](decisions.md).
