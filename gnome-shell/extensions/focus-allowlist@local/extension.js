// Local extension: GNOME refuses focus requests that come without a valid activation
// token (e.g. Crow Translate raised from a D-Bus shortcut), so Crow's window stays
// behind others. Two ways to fix it, both limited to allow-listed apps:
//  1. D-Bus method local.FocusAllowlist.Activate(appKey) — called by ~/.local/bin/crow-wayland
//     right after it asks Crow to show a window; activates that app's newest visible window.
//  2. Fallback: when an allow-listed window "demands attention", activate it.
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const APPS = {
    crow: {wmClass: ['crow', 'io.crow_translate.CrowTranslate'],
           appId: ['io.crow_translate.CrowTranslate.desktop']},
};
const DEBUG = false;

const IFACE = `<node><interface name="local.FocusAllowlist">
  <method name="Activate"><arg type="s" direction="in" name="app"/><arg type="b" direction="out" name="ok"/></method>
</interface></node>`;

function log(msg) { if (DEBUG) console.log(`[focus-allowlist] ${msg}`); }

function matchApp(window) {
    const wmClass = window.get_wm_class();
    const appId = Shell.WindowTracker.get_default().get_window_app(window)?.get_id();
    for (const [key, a] of Object.entries(APPS))
        if (a.wmClass.includes(wmClass) || a.appId.includes(appId)) return key;
    return null;
}

function describe(w) {
    return `class=${w.get_wm_class()} title="${w.get_title()}" type=${w.get_window_type()} ` +
           `skipTaskbar=${w.is_skip_taskbar()} focus=${w.has_focus()} minimized=${w.minimized}`;
}

export default class FocusAllowlist extends Extension {
    enable() {
        this._ids = ['window-demands-attention', 'window-marked-urgent'].map(sig =>
            global.display.connect(sig, (_d, w) => this._onAttention(sig, w)));
        this._dbus = Gio.DBusExportedObject.wrapJSObject(IFACE, this);
        this._dbus.export(Gio.DBus.session, '/local/FocusAllowlist');
        log('enabled');
    }

    disable() {
        for (const id of this._ids ?? []) global.display.disconnect(id);
        this._ids = null;
        this._dbus?.unexport();
        this._dbus = null;
    }

    // D-Bus: activate the newest visible window of an allow-listed app.
    Activate(appKey) {
        if (!APPS[appKey]) return false;
        const wins = global.display.list_all_windows()
            .filter(w => matchApp(w) === appKey && !w.minimized && w.showing_on_its_workspace())
            .sort((a, b) => b.get_stable_sequence() - a.get_stable_sequence());
        log(`Activate(${appKey}): ${wins.length} candidate(s)` + (wins[0] ? `; newest ${describe(wins[0])}` : ''));
        if (!wins.length) return false;
        Main.activateWindow(wins[0]);
        return true;
    }

    _onAttention(sig, window) {
        if (!window) return;
        const key = matchApp(window);
        log(`${sig}: ${describe(window)} allow=${key ?? 'no'}`);
        if (key && !window.has_focus()) Main.activateWindow(window);
    }
}
