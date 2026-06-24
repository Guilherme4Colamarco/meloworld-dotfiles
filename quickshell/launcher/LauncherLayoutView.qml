import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    // ── API ───────────────────────────────────────────────────────────────
    signal dismissed()

    property var filtered:      []
    property int selectedIndex: 0

    function setFilter(query) {
        _query = query
        _applyFilter()
    }

    function navigateUp()      { _move(-1) }
    function navigateDown()    { _move(+1) }
    function navigateTab()     { _move(+1) }
    function navigateBacktab() { _move(-1) }

    function confirm() {
        if (selectedIndex >= 0 && selectedIndex < filtered.length) {
            setLayoutProc.apply(filtered[selectedIndex].name)
            root.dismissed()
        }
    }

    // ── Internal ──────────────────────────────────────────────────────────
    property string _query: ""

    // layout options: tile, scroller, grid, deck, monocle, center_tile, vertical_tile, vertical_scroller, dwindle
    readonly property var _layouts: [
        { name: "dwindle",           icon: "󰕢", label: "Dwindle",           desc: "Binary space partition"  },
        { name: "tile",              icon: "󰕘", label: "Tile",              desc: "Master + stack"           },
        { name: "vertical_tile",     icon: "󰕤", label: "Vertical Tile",     desc: "Master + vertical stack"  },
        { name: "scroller",          icon: "󰤼", label: "Scroller",          desc: "Horizontal scroller"      },
        { name: "vertical_scroller", icon: "󰐌", label: "Vertical Scroller", desc: "Vertical scroller"        },
        { name: "grid",              icon: "󰙝", label: "Grid",              desc: "Equal-size grid"          },
        { name: "deck",              icon: "󰒘", label: "Deck",              desc: "Stacked windows"          },
        { name: "monocle",           icon: "󰆥", label: "Monocle",           desc: "Single focused window"    },
        { name: "center_tile",       icon: "󰕦", label: "Center Tile",       desc: "Centered master"          }
    ]

    Component.onCompleted: _applyFilter()

    onVisibleChanged: {
        if (visible) {
            _applyFilter()  // already resets selectedIndex
            list.positionViewAtBeginning()
        }
    }

    function _applyFilter() {
        var q = _query.toLowerCase()
        var result = []
        for (var i = 0; i < _layouts.length; i++) {
            var l = _layouts[i]
            if (q === "" || l.label.toLowerCase().includes(q) || l.name.toLowerCase().includes(q))
                result.push(l)
        }
        filtered = result
        selectedIndex = filtered.length > 0 ? 0 : -1
    }

    function _move(delta) {
        if (filtered.length === 0) return
        var next = Math.max(0, Math.min(selectedIndex + delta, filtered.length - 1))
        selectedIndex = next
        list.positionViewAtIndex(next, ListView.Contain)
    }

    // ── Apply layout via MangoWM IPC ──────────────────────────────────────
    Process {
        id: setLayoutProc
        running: false
        command: ["true"]

        function apply(layoutName) {
            setLayoutProc.command = ["mmsg", "dispatch", "setlayout," + layoutName]
            setLayoutProc.running = false
            setLayoutProc.running = true
        }
    }

    // ── List ──────────────────────────────────────────────────────────────
    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 2
        model: root.filtered
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData
            required property int index

            width:  list.width
            height: 44

            Rectangle {
                anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                radius: 8
                color: (rowHover.containsMouse || root.selectedIndex === index)
                       ? PanelColors.rowBackground : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    // ── Icon ─────────────────────────────────────────────
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:            modelData.icon
                        font.pixelSize:  20
                        font.family:     "JetBrainsMono Nerd Font"
                        color: (root.selectedIndex === index || rowHover.containsMouse)
                               ? PanelColors.launcher : PanelColors.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    // ── Name ─────────────────────────────────────────────
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.label
                        font.pixelSize: 16
                        font.bold:      true
                        font.family:    "JetBrainsMono Nerd Font"
                        color:          PanelColors.textMain
                        Behavior on color { ColorAnimation { duration: PanelColors.transitionDuration } }
                        width:          160
                        elide:          Text.ElideRight
                    }

                    // ── Description ───────────────────────────────────────
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.desc
                        font.pixelSize: 13
                        font.family:    "JetBrainsMono Nerd Font"
                        color:          PanelColors.textDim
                        Behavior on color { ColorAnimation { duration: PanelColors.transitionDuration } }
                        elide:          Text.ElideRight
                        width:          list.width - 12 - 28 - 12 - 160 - 12 - 24 - 8
                    }
                }

                MouseArea {
                    id:           rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onEntered:    root.selectedIndex = index
                    onClicked: {
                        setLayoutProc.apply(modelData.name)
                        root.dismissed()
                    }
                }
            }
        }
    }
}
