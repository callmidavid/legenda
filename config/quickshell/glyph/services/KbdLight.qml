pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// подсветка клавиатуры: LED *kbd_backlight* (ThinkPad и подобные), значения 0…max — обычно 0…2.
// Устройство ищем сами: brightnessctl по умолчанию берёт первый LED, а это может быть caps lock.
// Нет такого LED (обычная клавиатура) — dev пустой, available false, панель регулятор не показывает.
Singleton {
    id: root

    property string name: ""       // tpacpi::kbd_backlight
    property string dev: ""        // /sys/class/leds/<имя>
    property int raw: 0            // 0…max
    property int max: 0
    property int last: 1           // куда вернуть при включении; ноль не запоминаем

    readonly property bool available: dev !== "" && max > 0
    readonly property bool on: raw > 0

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        const m = parseInt(maxFile.text());
        if (!isNaN(m)) max = m;
        if (!isNaN(v)) {
            raw = v;
            if (v > 0) last = v;
        }
    }
    // значение ставим сразу, не ждём brightnessctl: панель не мигает, а чтение через 300 мс сверит
    function set(v) {
        if (!available) return;
        const r = Math.max(0, Math.min(max, Math.round(v)));
        raw = r;
        if (r > 0) last = r;
        sync.restart();
        Quickshell.execDetached(["brightnessctl", "-q", "--class=leds", "--device=" + name, "set", String(r)]);
    }
    // панель: включить на последний уровень / выключить
    function toggle() { set(on ? 0 : last); }
    // клавиша: цикл off → low → … → max → off
    function cycle() { set(raw >= max ? 0 : raw + 1); }

    Timer { id: sync; interval: 300; onTriggered: root.read() }

    GlobalShortcut { appid: "shell"; name: "kbdLight"; description: "подсветка клавиатуры"; onPressed: root.cycle() }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockAllReads: true; printErrors: false }
    FileView { id: maxFile; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds | grep -m1 kbd_backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                if (!n) return;
                root.name = n;
                root.dev = "/sys/class/leds/" + n;
                root.read();
            }
        }
    }
    // LED поменяли мимо нас (Fn+Space на тех моделях, где он доходит, или brightnessctl) — перечитываем
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=leds"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) root.read(); } }
    }
}
