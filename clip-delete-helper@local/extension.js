import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const TARGET_UUID = 'clipboard-history@alexsaveau.dev';

const IFACE_XML = `
<node>
  <interface name="dev.local.ClipDeleteHelper">
    <method name="DeleteLatest">
      <arg type="b" direction="out" name="deleted"/>
    </method>
  </interface>
</node>`;

export default class ClipDeleteHelperExtension extends Extension {
  enable() {
    this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(IFACE_XML, this);
    this._dbusImpl.export(Gio.DBus.session, '/dev/local/ClipDeleteHelper');
  }

  disable() {
    this._dbusImpl?.unexport();
    this._dbusImpl = undefined;
  }

  // Same code path as clicking the trash icon on the newest history entry.
  DeleteLatest() {
    const indicator = Main.extensionManager.lookup(TARGET_UUID)?.stateObj
      ?.clipboardIndicator;
    const entry = indicator?.entries?.last();
    if (!entry) return false;

    indicator._deleteEntryAndRestoreLatest(entry);
    return true;
  }
}
