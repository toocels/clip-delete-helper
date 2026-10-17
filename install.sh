#!/usr/bin/env bash
# Install Clip Move Recent Down (GNOME Shell extension + CLI command).
# Usage: ./install.sh [--keybinding]
#   --keybinding   also register a Ctrl+I custom shortcut that runs
#                  clip-move-latest-down (GNOME custom-keybindings).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="clip-move-recent-down@local"
OLD_UUID="clip-delete-helper@local"
EXT_DST="$HOME/.local/share/gnome-shell/extensions/$UUID"
OLD_EXT_DST="$HOME/.local/share/gnome-shell/extensions/$OLD_UUID"
MOVE_BIN_DST="$HOME/.local/bin/clip-move-latest-down"
OLD_BIN_DST="$HOME/.local/bin/clip-delete-latest"

WANT_KEYBINDING=0
for arg in "$@"; do
  case "$arg" in
    --keybinding) WANT_KEYBINDING=1 ;;
    *) echo "install.sh: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if ! command -v gnome-shell >/dev/null 2>&1 && ! command -v gnome-extensions >/dev/null 2>&1; then
  echo "install.sh: this doesn't look like a GNOME Shell session (no gnome-shell/gnome-extensions found)." >&2
  exit 1
fi

if [[ -d "$OLD_EXT_DST" ]]; then
  echo "Removing old extension at $OLD_EXT_DST"
  if command -v gnome-extensions >/dev/null 2>&1; then
    gnome-extensions disable "$OLD_UUID" 2>/dev/null || true
  fi
  rm -rf "$OLD_EXT_DST"
fi
if [[ -e "$OLD_BIN_DST" ]]; then
  echo "Removing old command at $OLD_BIN_DST"
  rm -f "$OLD_BIN_DST"
fi

echo "Installing extension to $EXT_DST"
mkdir -p "$EXT_DST"
cp "$SRC_DIR/$UUID/extension.js" "$SRC_DIR/$UUID/metadata.json" "$EXT_DST/"

echo "Installing command to $MOVE_BIN_DST"
mkdir -p "$HOME/.local/bin"
cp "$SRC_DIR/bin/clip-move-latest-down" "$MOVE_BIN_DST"
chmod +x "$MOVE_BIN_DST"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: $HOME/.local/bin is not on PATH. Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your shell rc file." ;;
esac

NEEDS_RELOGIN=0
WAS_ENABLED=0
if command -v gnome-extensions >/dev/null 2>&1; then
  if gnome-extensions list --enabled 2>/dev/null | grep -qx "$UUID"; then
    WAS_ENABLED=1
    gnome-extensions disable "$UUID" 2>/dev/null || true
  fi
  if gnome-extensions enable "$UUID" 2>/dev/null; then
    echo "Extension enabled: $UUID"
  else
    NEEDS_RELOGIN=1
  fi
else
  NEEDS_RELOGIN=1
fi

if [[ "$NEEDS_RELOGIN" -eq 1 ]]; then
  cat >&2 <<EOF

GNOME Shell hasn't picked up the new extension yet (it only scans the
extensions folder on login). Log out and back in, then run:
  gnome-extensions enable $UUID
EOF
else
  cat >&2 <<EOF

Note: GNOME Shell on Wayland caches an extension's JS module for the whole
session, so enabling a new UUID alone won't replace a still-running copy of
the old extension's code. Log out and back in once for this to fully take
effect.
EOF
fi

if [[ "$WANT_KEYBINDING" -eq 1 ]]; then
  SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
  PATH_PREFIX="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  existing="$(gsettings get "$SCHEMA" custom-keybindings)"

  # Reuse an existing slot already pointed at either binary instead of adding
  # a duplicate.
  slot=""
  for p in $(echo "$existing" | grep -oE "$PATH_PREFIX/custom[0-9]+/"); do
    cmd="$(gsettings get "$SCHEMA.custom-keybinding:$p" command 2>/dev/null | tr -d "'")"
    if [[ "$cmd" == "$MOVE_BIN_DST" || "$cmd" == "$OLD_BIN_DST" ]]; then
      slot="$p"
      break
    fi
  done

  if [[ -z "$slot" ]]; then
    # Find the lowest free customN slot instead of assuming one.
    n=0
    while [[ "$existing" == *"$PATH_PREFIX/custom$n/"* ]]; do
      n=$((n + 1))
    done
    slot="$PATH_PREFIX/custom$n/"

    if [[ "$existing" == "@as []" ]]; then
      new_list="['$slot']"
    else
      new_list="${existing%]}, '$slot']"
    fi
    gsettings set "$SCHEMA" custom-keybindings "$new_list"
  fi

  gsettings set "$SCHEMA.custom-keybinding:$slot" name "Move latest clipboard history entry down"
  gsettings set "$SCHEMA.custom-keybinding:$slot" command "$MOVE_BIN_DST"
  gsettings set "$SCHEMA.custom-keybinding:$slot" binding "<Control>i"
  echo "Keybinding registered: Ctrl+I -> clip-move-latest-down ($slot)"
fi

echo "Done."
