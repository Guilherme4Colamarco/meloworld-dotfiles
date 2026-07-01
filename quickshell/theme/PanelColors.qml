pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "."

Singleton {
    readonly property bool isDark: IrisColors.isDark
    readonly property int transitionDuration: 250

    // Surfaces
    readonly property color barBackground:     IrisColors.bg
    // Bar pills should read as the darkest neutral part of the Iris palette,
    // not as separate colored blocks. Accent colors still exist for popups,
    // rings and borders elsewhere, but the top-bar pill fill stays neutral.
    readonly property color pillBackground:    IrisColors.bg
    readonly property color pillHover:         IrisColors.surface
    readonly property color pillBorder:        IrisColors.dim
    // Foreground used on colored/accent blocks. Keep it deliberately dark in
    // dark mode so labels/icons read as the opposite of bright accent fills.
    readonly property color pillForeground:    isDark ? "#101216" : "#f6f1e7"
    readonly property color overlayBackground: "#66000000"

    // Accents
    readonly property color launcher:          IrisColors.accent
    readonly property color battery:           IrisColors.yellow
    readonly property color network:           IrisColors.accent
    readonly property color audio:             IrisColors.accent
    readonly property color clock:             IrisColors.fg
    readonly property color date:              IrisColors.green
    readonly property color brightness:        IrisColors.yellow
    readonly property color bluetooth:         IrisColors.accent
    readonly property color session:           IrisColors.red
    readonly property color dashboard:         IrisColors.surface

    readonly property color tray:              IrisColors.surface
    readonly property color workspaceActive:   IrisColors.fg
    readonly property color workspaceInactive: IrisColors.surface
    readonly property color titleBackground:   IrisColors.surface
    readonly property color titleForeground:   IrisColors.fg

    readonly property color popupBackground:   IrisColors.bg
    readonly property color rowBackground:     IrisColors.surface
    readonly property color trackBackground:   IrisColors.dim
    readonly property color border:            IrisColors.dim

    // Text
    // High-contrast text layer: bright on dark neutral cards, dark on bright
    // accent pills. Avoid using Iris dim directly for UI labels because it can
    // land too close to row/card backgrounds depending on the wallpaper.
    readonly property color textMain:          isDark ? "#f7f1e6" : "#101216"
    readonly property color textDim:           isDark ? "#c9c2b5" : "#424a57"
    // Accent-colored text/icons on neutral dark surfaces. Do not use
    // pillForeground here: pillForeground is deliberately dark for text placed
    // on bright/accent-filled buttons.
    readonly property color textAccent:        IrisColors.accent
    readonly property color textBox:           IrisColors.surface
    readonly property color textBoxDim:        isDark ? "#a79f91" : "#5b6472"

    // Status
    readonly property color scanning:          IrisColors.accent
    readonly property color networkScanning:   IrisColors.accent
    readonly property color pairing:           IrisColors.yellow
    readonly property color error:             IrisColors.red

    // Dashboard specific
    readonly property color dashboardBackground: IrisColors.bg
    readonly property color dashboardCard:       IrisColors.surface
    readonly property color dashboardAccent:     IrisColors.accent
    readonly property color dashboardStripe:     IrisColors.dim

    readonly property color profile:           IrisColors.green
    readonly property color system:            IrisColors.accent

    readonly property color cpuRing:           IrisColors.red
    readonly property color ramRing:           IrisColors.accent
    readonly property color gpuRing:           IrisColors.green

    // Functions
    function profileColor(profile) {
        if (profile === PowerProfile.PowerSaver)  return IrisColors.green
        if (profile === PowerProfile.Performance) return IrisColors.red
        return IrisColors.yellow
    }

    property var _hashCache: ({})
    function hashColor(str) {
        if (!str || str === "") return IrisColors.dim
        if (_hashCache[str + isDark]) return _hashCache[str + isDark]

        var hash = 0
        for (var i = 0; i < str.length; i++) {
            hash = str.charCodeAt(i) + ((hash << 5) - hash)
            hash = hash & hash
        }

        var palette = [
            IrisColors.accent, IrisColors.green, IrisColors.yellow,
            IrisColors.red, IrisColors.fg, IrisColors.dim
        ]

        var result = palette[Math.abs(hash) % palette.length]
        _hashCache[str + isDark] = result
        return result
    }
}
