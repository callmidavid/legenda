import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// бар: вертикальная пилюля у левого края. Сверху знак (кольцо из 16 точек) — лаунчер, центр краснеет, пока запись или микрофон.
// Воркспейсы точками, заголовок окна столбиком, часы Doto по центру, трей снизу — клик открывает быстрые настройки
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked
    signal clockClicked

    anchors { left: true; top: true; bottom: true }
    implicitWidth: Math.ceil(78 * Theme.s)
    color: "transparent"
    WlrLayershell.namespace: "glyph-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    // шесть точек, больше — если занят или открыт дальний
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // hyprland 0.56 с lua: dispatch принимает lua-выражение
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        Rectangle {
            id: pill
            x: 14
            y: 14
            width: 64
            height: parent.height - 28
            radius: 32
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

            // знак: кольцо из точек, центр — красный, пока что-то пишет
            Item {
                id: mark
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: 34
                height: 34
                Ring { anchors.fill: parent; n: 16; dot: 3 }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    color: Sys.live ? Theme.red : Theme.fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.markClicked() }
            }

            // воркспейсы: текущий вытягивается в белую пилюлю, занятые серые, пустые — линия
            Column {
                id: ws
                anchors.horizontalCenter: parent.horizontalCenter
                y: mark.y + mark.height + 24
                spacing: 8

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index
                        readonly property int n: index + 1
                        readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                        readonly property bool on: root.active === n
                        width: 8
                        height: on ? 28 : 8
                        radius: 4
                        color: on ? Theme.fg : occ ? Theme.grey : Theme.s3
                        Behavior on height { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.go(parent.n) }
                    }
                }
            }

            // заголовок окна, повёрнутый: от воркспейсов до часов
            Item {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                y: ws.y + ws.height + 24
                width: 20
                height: Math.max(0, clk.y - 24 - y)
                clip: true
                Lb {
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: parent.height
                    rotation: 90
                    elide: Text.ElideRight
                    visible: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                    text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                    px: 11
                }
            }

            // часы столбиком: 14 над 32 и день. Клик — календарь и фокус-таймер (cal/Cal)
            Column {
                id: clk
                anchors.centerIn: parent
                TapHandler { onTapped: root.clockClicked() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.hh(clock.date)
                    font.pixelSize: 30
                }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "mm")
                    font.pixelSize: 30
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 8
                    text: Qt.locale("en_US").toString(clock.date, "ddd d")
                    px: 10
                }
            }

            // трей: раскладка, сеть, bluetooth, звук (колесо — громкость), уведомления, батарея, питание
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 22 }
                spacing: 20

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20

                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Sys.layout; px: 10 }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"
                        color: root.wifi?.connected ? Theme.fg : Theme.grey
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
                        color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.muted ? "\u{F075F}" : "\u{F057E}"
                        WheelHandler { onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
                        color: Notes.list.length ? Theme.fg : Theme.grey
                    }
                    // в вертикальном баре батарея стоит, заряд растёт снизу. На зарядке — молния сверху, заливка дышит, пока заряжается
                    Column {
                        id: batc
                        visible: root.bat.isLaptopBattery
                        HoverHandler { id: batHov }
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        readonly property bool ac: !UPower.onBattery
                        readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
                        readonly property bool low: !ac && root.bat.percentage < 0.15
                        property real pulse: 1
                        SequentialAnimation on pulse {
                            running: batc.charging
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) batc.pulse = 1
                            NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                        }
                        Icon { visible: batc.ac; anchors.horizontalCenter: parent.horizontalCenter; text: "\u{F140B}"; font.pixelSize: 14 }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 14
                            height: 26
                            radius: 7
                            color: "transparent"
                            border { width: 1.5; color: Theme.grey }
                            Rectangle {
                                x: 3
                                width: parent.width - 6
                                height: (parent.height - 6) * root.bat.percentage
                                anchors { bottom: parent.bottom; bottomMargin: 3 }
                                radius: 4
                                color: batc.low ? Theme.red : Theme.fg
                                opacity: batc.pulse
                            }
                        }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
                    }

                    TapHandler { onTapped: root.trayClicked() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                // режим питания засечками (Rules.modes): ultra — одна, performance — все; клик — следующий,
                // наведение (и на батарею) — карточка с выбором
                Item {
                    id: ticks
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 22
                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: Rules.modeCount
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 3
                                height: 5 + index * 3
                                radius: 1.5
                                color: index <= Rules.mode ? Theme.fg : Theme.s3
                            }
                        }
                    }
                    HoverHandler { id: tickHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u{F0425}"
                    color: pwr.hovered ? Theme.fg : Theme.grey
                    HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.powerClicked() }
                }
            }
        }
    }

    // ---- батарея и режим питания: навёл на батарею или засечки — карточка справа от бара, как поповер caelestia.
    // Заряд Doto, статус, шкала; ниже режимы кругами с засечками — клик выбирает, под курсором — что он делает.
    // Ушёл и с бара, и с карточки — гаснет ----
    readonly property bool powHot: batHov.hovered || tickHov.hovered || popHov.hovered
    property bool powOpen: false
    property int powPeek: -1
    onPowHotChanged: powHot ? powOpenT.restart() : powCloseT.restart()
    Timer { id: powOpenT; interval: 180; onTriggered: if (root.powHot) root.powOpen = true }
    Timer { id: powCloseT; interval: 300; onTriggered: if (!root.powHot) root.powOpen = false }
    function hm(sec) { const m = Math.round(sec / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    readonly property string batState: root.bat.state === UPowerDeviceState.Charging
        ? "charging" + (root.bat.timeToFull ? ` · full in ${hm(root.bat.timeToFull)}` : "")
        : !UPower.onBattery ? "on ac · full"
        : "on battery" + (root.bat.timeToEmpty ? ` · ${hm(root.bat.timeToEmpty)} left` : "")

    PopupWindow {
        id: pop
        property real t: root.powOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        visible: t > 0
        // от правого края пилюли бара (засечки в ней по центру: 40 + 12) с зазором 14; низом — по засечкам, растёт вверх
        anchor.item: ticks
        anchor.rect: Qt.rect(ticks.width + 12 + 14, ticks.height, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        implicitWidth: Math.ceil(440 * Theme.s)
        implicitHeight: Math.ceil(card.height * Theme.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: card
                width: 440
                height: body.height + 52
                radius: 36
                color: Theme.s1
                border { width: 1; color: Theme.s2 }
                opacity: pop.t
                transform: Translate { x: -16 * (1 - pop.t) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26
                    y: 26
                    width: parent.width - 52
                    spacing: 18

                    Row {
                        spacing: 14
                        Num { text: Math.round(root.bat.percentage * 100); font.pixelSize: 72 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Lb { text: "% battery"; color: Theme.fg }
                            Lb { text: root.batState }
                        }
                    }
                    Seg { width: parent.width; height: 6; n: 24; f: root.bat.percentage; on: batc.low ? Theme.red : Theme.fg }

                    Lb { topPadding: 6; text: "power mode" }
                    Row {
                        spacing: (body.width - Rules.modeCount * 80) / Math.max(1, Rules.modeCount - 1)
                        Repeater {
                            model: Rules.modeCount
                            Column {
                                id: mo
                                required property int index
                                readonly property bool on: Rules.mode === index
                                spacing: 10
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: mo.on ? Theme.fg : moHov.hovered ? Theme.s3 : Theme.s2
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                    // засечки: сколько горит — такая сила
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5
                                                height: 8 + index * 6
                                                radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Theme.ink : Theme.fg) : (mo.on ? Theme.mute : Theme.s3)
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: moHov
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1
                                    }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Lb {
                        readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode
                        width: parent.width
                        elide: Text.ElideRight
                        text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz`
                    }
                }
            }
        }
    }
}
