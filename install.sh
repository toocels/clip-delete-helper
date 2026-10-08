#!/usr/bin/env bash
# Install Clip Delete Helper (GNOME Shell extension + CLI command).
# Usage: ./install.sh [--keybinding]
#   --keybinding   also register a Ctrl+I custom shortcut that runs
#                  clip-delete-latest (GNOME custom-keybindings).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="clip-delete-helper@local"
EXT_DST="$HOME/.local/share/gnome-shell/extensions/$UUID"
BIN_DST="$HOME/.local/bin/clip-delete-latest"

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

echo "Installing extension to $EXT_DST"
mkdir -p "$EXT_DST"
cp "$SRC_DIR/$UUID/extension.js" "$SRC_DIR/$UUID/metadata.json" "$EXT_DST/"

echo "Installing command to $BIN_DST"
mkdir -p "$HOME/.local/bin"
cp "$SRC_DIR/bin/clip-delete-latest" "$BIN_DST"
chmod +x "$BIN_DST"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: $HOME/.local/bin is not on PATH. Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your shell rc file." ;;
esac

NEEDS_RELOGIN=0
if command -v gnome-extensions >/dev/null 2>&1; then
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
fi

if [[ "$WANT_KEYBINDING" -eq 1 ]]; then
  SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
  PATH_PREFIX="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  existing="$(gsettings get "$SCHEMA" custom-keybindings)"

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
  gsettings set "$SCHEMA.custom-keybinding:$slot" name "Delete latest clipboard history entry"
  gsettings set "$SCHEMA.custom-keybinding:$slot" command "$BIN_DST"
  gsettings set "$SCHEMA.custom-keybinding:$slot" binding "<Control>i"
  echo "Keybinding registered: Ctrl+I -> clip-delete-latest (slot: custom$n)"
fi

echo "Done."
