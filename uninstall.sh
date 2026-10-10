#!/usr/bin/env bash
# Uninstall Clip Delete Helper (GNOME Shell extension + CLI command).
# Usage: ./uninstall.sh [--keybinding]
#   --keybinding   also remove the custom Ctrl+I shortcut, if one was
#                  registered by install.sh --keybinding.
#
# Note: disabling/removing the extension via GNOME Extension Manager (the
# app) works fine too. This script additionally cleans up the CLI command
# and, optionally, the custom keybinding, which Extension Manager won't do.
set -euo pipefail

UUID="clip-delete-helper@local"
EXT_DST="$HOME/.local/share/gnome-shell/extensions/$UUID"
BIN_DST="$HOME/.local/bin/clip-delete-latest"

WANT_KEYBINDING=0
for arg in "$@"; do
  case "$arg" in
    --keybinding) WANT_KEYBINDING=1 ;;
    *) echo "uninstall.sh: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions disable "$UUID" 2>/dev/null || true
fi

echo "Removing $EXT_DST"
rm -rf "$EXT_DST"

echo "Removing $BIN_DST"
rm -f "$BIN_DST"

if [[ "$WANT_KEYBINDING" -eq 1 ]]; then
  SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
  PATH_PREFIX="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  existing="$(gsettings get "$SCHEMA" custom-keybindings)"

  slot=""
  for p in $(echo "$existing" | grep -oE "$PATH_PREFIX/custom[0-9]+/"); do
    cmd="$(gsettings get "$SCHEMA.custom-keybinding:$p" command 2>/dev/null | tr -d "'")"
    if [[ "$cmd" == "$BIN_DST" ]]; then
      slot="$p"
      break
    fi
  done

  if [[ -n "$slot" ]]; then
    new_list="$(echo "$existing" | sed -E "s#'$slot',? ?##; s#, \]#\]#; s#\[, #\[#")"
    gsettings set "$SCHEMA" custom-keybindings "$new_list"
    gsettings reset "$SCHEMA.custom-keybinding:$slot" name
    gsettings reset "$SCHEMA.custom-keybinding:$slot" command
    gsettings reset "$SCHEMA.custom-keybinding:$slot" binding
    echo "Keybinding removed (was: $slot)"
  else
    echo "No matching keybinding found, nothing to remove."
  fi
fi

echo "Done."
