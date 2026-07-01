pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    // Cores Fallback (Material Design atual)
    property color bg:      "#1e1e2e"
    property color fg:      "#cdd6f4"
    property color surface: "#313244"
    property color dim:     "#6c7086"
    property color accent:  "#89b4fa"
    property color red:     "#f38ba8"
    property color green:   "#a6e3a1"
    property color yellow:  "#f9e2af"
    
    // Cores anteriores (para animação do Kitty)
    property color _prevBg:      bg
    property color _prevFg:      fg
    property color _prevSurface: surface
    property color _prevDim:     dim
    property color _prevAccent:  accent
    property color _prevRed:     red
    property color _prevGreen:   green
    property color _prevYellow:  yellow

    // ThemeState is the user's switch. When Dark Mode is on, Iris is forced
    // with --dark 1 even if the wallpaper is bright. When off, Iris gets
    // --dark 0 for an explicit light palette.
    readonly property bool isDark: ThemeState.isDark
    property string currentWallpaper: ""

    signal colorsChanged()

    // 1. Observador de Wallpaper Seguro
    FileView {
        path: Quickshell.env("HOME") + "/.cache/meloworld/last-wallpaper"
        onLoaded: {
            root.loadWallpaperText(text())
        }
        onTextChanged: {
            root.loadWallpaperText(text())
        }
    }

    function loadWallpaperText(raw) {
        var content = String(raw || "").trim()
        if (!content) return
        // Format is "image:/path/to/file" or "video:/path/to/file".
        var parts = content.split(":")
        if (parts.length > 1) parts.shift()
        var path = parts.join(":")
        if (path && path !== root.currentWallpaper) {
            root.currentWallpaper = path
            refresh()
        }
    }

    function refresh() {
        if (!root.currentWallpaper) return
        irisProc.running = false
        irisProc.running = true
    }

    // 2. Parse Seguro com Fallbacks
    function normalizeIrisPalette(c) {
        // Preserve Iris accents, but do not use strongly saturated wallpaper
        // colors as app/window surfaces. The current Desert-City gif produces
        // olive bg/surface values, which makes Kitty/GTK look neon green.
        if (root.isDark) {
            c.bg      = "#1d140f"
            c.surface = "#70462b"
            c.dim     = "#9b6a43"
            c.fg      = "#f3eadb"
        } else {
            c.bg      = "#f3eadb"
            c.surface = "#e3cfb4"
            c.dim     = "#8b684d"
            c.fg      = "#21160f"
        }
        return c
    }

    function applyFromJson(data) {
        try {
            var c = normalizeIrisPalette(JSON.parse(data))
            
            _prevBg = bg; _prevFg = fg; _prevSurface = surface;
            _prevDim = dim; _prevAccent = accent; _prevRed = red;
            _prevGreen = green; _prevYellow = yellow;
            
            bg      = c.bg      || bg
            fg      = c.fg      || fg
            surface = c.surface || surface
            dim     = c.dim     || dim
            accent  = c.accent  || accent
            red     = c.red     || red
            green   = c.green   || green
            yellow  = c.yellow  || yellow
            
            colorsChanged()
        } catch(e) { 
            console.warn("IrisColors: Falha ao fazer parse do output do iris. Usando fallback.", e) 
        }
    }

    Process {
        id: irisProc
        command: [
            "bash", "-lc",
            "command -v iris >/dev/null 2>&1 || exit 0; exec iris \"$1\" --dark \"$2\" --json-only",
            "iris-wrapper", root.currentWallpaper, root.isDark ? "1" : "0"
        ]
        running: false
        stdout: SplitParser {
            splitMarker: "" 
            onRead: data => root.applyFromJson(data)
        }
    }

    // --- ANIMAÇÃO E APLICAÇÃO EXTERNA --- //

    property int _kittyStep: 0
    property int _kittySteps: 5 // Reduzido de 10 para 5 (Performance)
    
    function interpolateColor(color1, color2, factor) {
        var c1 = Qt.color(color1); var c2 = Qt.color(color2)
        return Qt.rgba(c1.r + (c2.r - c1.r) * factor, c1.g + (c2.g - c1.g) * factor, c1.b + (c2.b - c1.b) * factor, 1.0)
    }

    Timer {
        id: kittyInterpolateTimer
        interval: 60 // 60ms * 5 steps = 300ms
        repeat: true
        onTriggered: {
            var t = _kittyStep / (_kittySteps - 1)
            t = t * t * (3.0 - 2.0 * t) // smoothstep
            
            var iBg = interpolateColor(_prevBg, bg, t).toString()
            var iFg = interpolateColor(_prevFg, fg, t).toString()
            var iAccent = interpolateColor(_prevAccent, accent, t).toString()
            var iSurface = interpolateColor(_prevSurface, surface, t).toString()
            var iRed = interpolateColor(_prevRed, red, t).toString()
            var iGreen = interpolateColor(_prevGreen, green, t).toString()
            var iYellow = interpolateColor(_prevYellow, yellow, t).toString()
            var iDim = interpolateColor(_prevDim, dim, t).toString()

            // Dispara para todos os sockets Kitty abertos. Meloworld now uses
            // the Alphonso-style fixed socket (/tmp/kitty-socket), while the
            // wildcard keeps compatibility with older per-instance sockets.
            kittyStepProc.command = ["bash", "-c",
                "for s in /tmp/kitty-socket /tmp/kitty-socket-*; do " +
                "[ -S \"$s\" ] || continue; " +
                "kitty @ --to unix:\"$s\" set-colors --all --configured " +
                "foreground=" + iFg + " background=" + iBg + " cursor=" + iAccent + " " +
                "color0=" + iSurface + " color8=" + iDim + " color1=" + iRed + " color9=" + iRed + " " +
                "color2=" + iGreen + " color10=" + iGreen + " color3=" + iYellow + " color11=" + iYellow + " " +
                "color4=" + iAccent + " color12=" + iAccent + " color5=" + iAccent + " color13=" + iAccent + " " +
                "color6=" + iAccent + " color14=" + iAccent + " color7=" + iFg + " color15=" + iFg + " " +
                " 2>/dev/null & done; wait"
            ]
            kittyStepProc.running = true
            
            if (_kittyStep >= _kittySteps - 1) kittyInterpolateTimer.stop()
            else _kittyStep++
        }
    }
    Process { id: kittyStepProc }

    Timer {
        id: applyDelay
        interval: 320 // Aguarda a animação do Kitty terminar
        onTriggered: {
            // 1. HYPRLAND BORDERS (Live sem reload, only if Hyprland exists)
            var actBorder = root.accent.toString().replace("#", "") + "ff"
            var inactBorder = root.dim.toString().replace("#", "") + "aa"
            hyprlandProc.command = ["bash", "-c",
                "command -v hyprctl >/dev/null 2>&1 || exit 0; " +
                "hyprctl keyword general:col.active_border 'rgba(" + actBorder + ")' && " +
                "hyprctl keyword general:col.inactive_border 'rgba(" + inactBorder + ")'"
            ]
            hyprlandProc.running = true

            // 2. Kitty/GTK/templates via script. Keeps shell quoting and file
            // writes outside QML and leaves safe fallbacks if Iris fails.
            postDelayProc.command = ["bash", "-c",
                "~/.config/meloworld-dotfiles/scripts/apply-iris-theme.sh " +
                JSON.stringify(root.currentWallpaper) + " " + (root.isDark ? "1" : "0")
            ]
            postDelayProc.running = true
        }
    }
    Process { id: hyprlandProc }
    Process { id: postDelayProc }

    onColorsChanged: {
        _kittyStep = 0
        kittyInterpolateTimer.restart()
        applyDelay.restart()
    }

    Connections {
        target: ThemeState
        function onIsDarkChanged() { root.refresh() }
    }
}
