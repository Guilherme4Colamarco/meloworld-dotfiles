//@ pragma IconTheme Papirus
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "polkit"
import "bar"
import "notifications"
import "osd"
import "dashboard"
import "launcher"
import "wallpaper"
import "screenshot"
import "theme"

ShellRoot {
    property bool wallpaperPickerVisible: false

    Process { id: wallpaperPickerStateProc }

    function setWallpaperPickerVisible(next) {
        wallpaperPickerVisible = next
        wallpaperPickerStateProc.command = ["bash", "-lc",
            "mkdir -p \"$HOME/.cache/meloworld\" && printf '%s\\n' \"$1\" > \"$HOME/.cache/meloworld/wallpaper-picker-visible\"",
            "wallpaper-visible", next ? "1" : "0"]
        wallpaperPickerStateProc.running = false
        wallpaperPickerStateProc.running = true
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { setWallpaperPickerVisible(!wallpaperPickerVisible) }
        function open(): void { setWallpaperPickerVisible(true) }
        function close(): void { setWallpaperPickerVisible(false) }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panelWin
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 50
            color: "transparent"
            exclusiveZone: implicitHeight
            Bar { id: bar; anchors.fill: parent }

            // Returns the X anchor for a right-bar popup centred under its trigger widget.
            // Pass the trigger widget and the popup's own implicitWidth.
            function popupX(widget, pWidth) {
                return Math.min(
                    bar.rightContainer.x + bar.rightBar.x + widget.x + widget.width / 2 - pWidth / 2,
                    bar.rightContainer.x + bar.rightContainer.width - pWidth
                )
            }

            function centerPopupX(pWidth) {
                return Math.round(panelWin.screen.width / 2 - pWidth / 2)
            }

            Repeater {
                model: [
                    { "source": "osd/AudioPopup.qml", "widget": bar.rightBar.audioWidget },
                    { "source": "osd/BrightnessPopup.qml", "widget": bar.rightBar.brightnessWidget },
                    { "source": "osd/PowerProfilePopup.qml", "widget": bar.rightBar.batteryWidget },
                    { "source": "osd/BluetoothPopup.qml", "widget": bar.rightBar.bluetoothWidget },
                    { "source": "osd/SessionPopup.qml", "widget": bar.rightBar.sessionWidget },
                    { "source": "osd/TrayPopup.qml", "widget": bar.rightBar.trayBar },
                    { "source": "osd/CalendarPopup.qml", "widget": bar.rightBar.dateWidget }
                ]
                delegate: Loader {
                    required property var modelData
                    source: modelData.source
                    asynchronous: true
                    onLoaded: {
                        item.anchor.window = panelWin
                        item.anchor.rect.y = Qt.binding(function() { return panelWin.height + 6 })
                        item.anchor.rect.x = Qt.binding(function() { return panelWin.popupX(modelData.widget, item.implicitWidth) })
                    }
                }
            }

            WifiPopup {
                screenObj: modelData
                xPos: panelWin.popupX(bar.rightBar.networkWidget, implicitWidth)
                anchorWindow: panelWin
            }

            MediaPopup {
                anchor.window: panelWin
                anchor.rect.x: panelWin.centerPopupX(implicitWidth)
                anchor.rect.y: panelWin.height + 6
            }

            Dashboard {
                screenObj: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        NotificationPopup {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        OsdWindow {
            required property var modelData
            screen: modelData
        }
    }
    PolkitDialog {}
    AppLauncher {}
    Variants {
        model: Quickshell.screens
        WallpaperPicker {
            required property var modelData
            screen: modelData
        }
    }
    ScreenshotUI {}
}
