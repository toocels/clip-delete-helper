# Clip Move Recent Down

A tiny GNOME Shell extension that lets a terminal command (or `Ctrl+I`) push
the newest entry in **GNOME Clipboard History**
(`clipboard-history@alexsaveau.dev` by SUPERCILEX) down the list by 50
positions, without deleting it, pasting it, or touching anything else.

## Intent

Meant to be used alongside **GNOME Clipboard History** — not as a
replacement for it. The use case: something's sitting at the top of your
clipboard history and you don't want it right there (e.g. you just copied
something you don't want to accidentally repaste), but you also don't want
to lose it. Pushing it down keeps it in history; scroll down in the
Clipboard History menu whenever you want to find it again.

## Why this exists

Clipboard History has no public API (no D-Bus interface, no CLI) to reorder
its own history from a terminal.

The obvious way to run arbitrary GNOME Shell JS from the outside is the
`org.gnome.Shell.Eval` D-Bus method. It doesn't work here: GNOME gates `Eval`
behind `global.context.unsafe_mode`, which can only be turned on by hand
(Looking Glass, or the "Unsafe Mode" Quick Settings toggle) and resets on
every screen lock. That's unusable for a reliable command.

So instead, this is a second, separate extension. It does **not** modify
Clipboard History's own files at all — it only reads its live state and
reorders its in-memory entry list, from inside the trusted GNOME Shell
process (extensions are allowed to do this; that's the whole point of the
extension API, unlike `Eval` which is deliberately locked down).

What `MoveLatestDown` does when called:
1. Looks up the running Clipboard History extension instance
   (`Main.extensionManager.lookup('clipboard-history@alexsaveau.dev').stateObj`).
2. Gets its newest history entry (`indicator.entries.last()`).
3. Walks 51 entries back in the history list (`entries` is a linked list,
   oldest at the head, newest at the tail) — 51, not 50, because the entry
   being moved is one of those positions itself.
4. Reinserts the entry right after that node, i.e. 50 positions down from the
   top — matching Clipboard History's own page size (`PAGE_SIZE = 50` in its
   `extension.js`), so the entry lands just past a full page instead of at an
   arbitrary spot. If history has fewer than 51 other entries, it's moved as
   far down as it can go, and the call reports nothing moved only if there's
   nowhere to move it (0 or 1 entries total).
5. Rebuilds just that one menu item at its new position — it does not touch
   the disk-backed entry order, favorites, or any other entry.

It's exported as a D-Bus method (`dev.local.ClipMoveRecentDown.MoveLatestDown`)
on the session bus so a shell script can call it.

## Requirements

- GNOME Shell (tested on shell-version 50) with the
  `clipboard-history@alexsaveau.dev` extension installed and enabled.
- `bash`, `gdbus` (part of glib2, present on any GNOME system).

## Repo layout

```
clip-move-recent-down@local/   the GNOME Shell extension (extension.js, metadata.json)
bin/clip-move-latest-down      the CLI command, calls the extension over D-Bus
install.sh                     installs both, per-user
uninstall.sh                   reverses install.sh
```

## Install

```bash
./install.sh                 # extension + CLI command only
./install.sh --keybinding     # also binds Ctrl+I to run it
```

This is per-user only — nothing is installed system-wide (no `/usr` files,
no root needed):

- Extension copied to `~/.local/share/gnome-shell/extensions/clip-move-recent-down@local/`
  (GNOME auto-discovers extensions here for the current user).
- `clip-move-latest-down` copied to `~/.local/bin/` (must be on `PATH`).

**First install only:** GNOME Shell only picks up a *newly added* extension
folder on the next login (Wayland has no "restart shell" like X11). If
`install.sh` can't enable it immediately, log out and back in once, then run:

```bash
gnome-extensions enable clip-move-recent-down@local
```

After that one-time relogin it loads automatically every session.

## Usage

```bash
clip-move-latest-down
```

or just press `Ctrl+I` (if installed with `--keybinding`, see below).

Pushes the newest Clipboard History entry down 50 positions (one full page)
in the history list, without touching the clipboard, favorites, or any other
entry. 50 is Clipboard History's default page size (`PAGE_SIZE` in its
`extension.js`), not an arbitrary number — to find an entry you moved, open
Clipboard History and scroll down past the current page.

## Keyboard shortcut

`install.sh --keybinding` binds `Ctrl+I` to run `clip-move-latest-down`
directly. It's registered as a GNOME custom keybinding (same mechanism as
Settings → Keyboard → Custom Shortcuts), added alongside any custom shortcuts
already on the machine rather than overwriting them. It shows up there as
"Move latest clipboard history entry down" if you want to change or remove it
visually instead.

**Gotcha:** `gnome-settings-daemon` runs custom-keybinding commands with a
bare environment — it does *not* source `.zshrc`/`.bashrc`, so anything
relying on `PATH` there breaks even though it works fine in a normal
terminal. Not an issue here since `clip-move-latest-down` only calls `gdbus`
by absolute resolution already.

### Dropped: paste-then-move

Originally tried a shortcut that would send a synthetic paste (via
`ydotool`, since GNOME Wayland blocks the old `xdotool` method for native
Wayland apps) and then act on that entry. Abandoned — paste timing against
the still-held physical modifier keys was unreliable (worked, then didn't,
then pasted with an annoying delay).

## Uninstall

```bash
./uninstall.sh                 # extension + CLI command
./uninstall.sh --keybinding     # also removes the Ctrl+I shortcut
```

Disabling/removing the extension via the **Extension Manager** GUI app works
fine too — but it won't remove `clip-move-latest-down` or the keybinding, so
prefer `uninstall.sh` for a full clean.

## License

GPLv3 — see [LICENSE](LICENSE).
