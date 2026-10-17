import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const TARGET_UUID = 'clipboard-history@alexsaveau.dev';

// Matches Clipboard History's own PAGE_SIZE constant — moving an entry down
// by this many positions pushes it past a full page.
const MOVE_AMOUNT = 50;

const IFACE_XML = `
<node>
  <interface name="dev.local.ClipMoveRecentDown">
    <method name="MoveLatestDown">
      <arg type="b" direction="out" name="moved"/>
    </method>
  </interface>
</node>`;

export default class ClipMoveRecentDownExtension extends Extension {
  enable() {
    this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(IFACE_XML, this);
    this._dbusImpl.export(Gio.DBus.session, '/dev/local/ClipMoveRecentDown');
  }

  disable() {
    this._dbusImpl?.unexport();
    this._dbusImpl = undefined;
  }

  // Moves the newest entry down MOVE_AMOUNT positions in history. `entries`
  // is ordered oldest (head) to newest (tail/last()), so "down" means
  // walking MOVE_AMOUNT+1 nodes back from the newest entry and re-inserting
  // it right after that node.
  MoveLatestDown() {
    const indicator = Main.extensionManager.lookup(TARGET_UUID)?.stateObj
      ?.clipboardIndicator;
    const entries = indicator?.entries;
    const entry = entries?.last();
    if (!entry) return false;

    let target = entry;
    for (let i = 0; i < MOVE_AMOUNT + 1 && target.prev; i++) {
      target = target.prev;
    }
    if (target === entry) return false; // history too short to move

    const insertIndex = Math.min(MOVE_AMOUNT, indicator.activeHistoryMenuItems);
    entry.menuItem?.destroy();
    target.append(entry);
    indicator._addEntry(entry, false, false, insertIndex);
    return true;
  }
}
