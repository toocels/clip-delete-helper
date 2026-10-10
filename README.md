# Clip Delete Helper

A tiny GNOME Shell extension that lets a terminal command delete the newest
entry in **GNOME Clipboard History** (`clipboard-history@alexsaveau.dev` by
SUPERCILEX), the same way clicking the trash icon on that entry would.

## Why this exists

Clicking the trash button on the top entry in Clipboard History calls the
extension's own `_deleteEntryAndRestoreLatest(entry)` method internally.
There's no public API (no D-Bus interface, no CLI) to trigger that from a
terminal.

The obvious way to run arbitrary GNOME Shell JS from the outside is the
`org.gnome.Shell.Eval` D-Bus method. It doesn't work here: GNOME gates `Eval`
behind `global.context.unsafe_mode`, which can only be turned on by hand
(Looking Glass, or the "Unsafe Mode" Quick Settings toggle) and resets on
every screen lock. That's unusable for a reliable command.

So instead, this is a second, separate extension. It does **not** modify
Clipboard History's own files at all — it only reads its live state and
calls its existing method, from inside the trusted GNOME Shell process
(extensions are allowed to do this; that's the whole point of the extension
API, unlike `Eval` which is deliberately locked down).

What it does when called:
1. Looks up the running Clipboard History extension instance
   (`Main.extensionManager.lookup('clipboard-history@alexsaveau.dev').stateObj`).
2. Gets its newest history entry (`indicator.entries.last()`).
3. Calls `indicator._deleteEntryAndRestoreLatest(entry)` — the exact function
   the trash button calls. This deletes only that one entry and restores the
   clipboard to the new latest entry, exactly like clicking the button.

It exports this as a D-Bus method (`dev.local.ClipDeleteHelper.DeleteLatest`)
on the session bus so a shell script can call it.

## Requirements

- GNOME Shell (tested on shell-version 50) with the
  `clipboard-history@alexsaveau.dev` extension installed and enabled.
- `bash`, `gdbus` (part of glib2, present on any GNOME system).

## Repo layout

```
clip-delete-helper@local/   the GNOME Shell extension (extension.js, metadata.json)
bin/clip-delete-latest      the CLI command, calls the extension over D-Bus
install.sh                  installs both, per-user
uninstall.sh                reverses install.sh
```

## Install

```bash
./install.sh                 # extension + CLI command only
./install.sh --keybinding     # also registers a Ctrl+I custom shortcut
```

This is per-user only — nothing is installed system-wide (no `/usr` files,
no root needed):

- Extension copied to `~/.local/share/gnome-shell/extensions/clip-delete-helper@local/`
  (GNOME auto-discovers extensions here for the current user).
- `clip-delete-latest` copied to `~/.local/bin/` (must be on `PATH`).

**First install only:** GNOME Shell only picks up a *newly added* extension
folder on the next login (Wayland has no "restart shell" like X11). If
`install.sh` can't enable it immediately, log out and back in once, then run:

```bash
gnome-extensions enable clip-delete-helper@local
```

After that one-time relogin it loads automatically every session.

## Usage

```bash
clip-delete-latest
```

Deletes the newest Clipboard History entry and restores the clipboard to
whatever is now newest — same as clicking the trash icon on it. Does not
touch favorites or any other entry.

## Keyboard shortcut

`install.sh --keybinding` binds `Ctrl+I` to run `clip-delete-latest` directly
— no paste involved, just deletes the newest entry. It's registered as a
GNOME custom keybinding (same mechanism as Settings → Keyboard → Custom
Shortcuts), added alongside any custom shortcuts already on the machine
rather than overwriting them. It shows up there as "Delete latest clipboard
history entry" if you want to change or remove it visually instead.

**Gotcha:** `gnome-settings-daemon` runs custom-keybinding commands with a
bare environment — it does *not* source `.zshrc`/`.bashrc`, so anything
relying on `PATH` there breaks even though it works fine in a normal
terminal. Not an issue here since `clip-delete-latest` only calls `gdbus` by
absolute resolution already.

### Dropped: paste-then-delete

Originally tried a second shortcut that would send a synthetic paste (via
`ydotool`, since GNOME Wayland blocks the old `xdotool` method for native
Wayland apps) and then delete that entry. Abandoned — paste timing against
the still-held physical modifier keys was unreliable (worked, then didn't,
then pasted with an annoying delay).

## Uninstall

```bash
./uninstall.sh                 # extension + CLI command
./uninstall.sh --keybinding     # also removes the Ctrl+I shortcut
```

Disabling/removing the extension via the **Extension Manager** GUI app works
fine too — but it won't remove `clip-delete-latest` or the keybinding, so
prefer `uninstall.sh` for a full clean.

## License

GPLv3 — see [LICENSE](LICENSE).
