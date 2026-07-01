import Quickshell
import Quickshell.Io
import "../theme"
import Quickshell.Wayland
import QtQuick
import QtMultimedia

PanelWindow {
    id: wallpaper

    property bool showing: false
    property bool ready: false
    property var walls: []
    property var filtered: []
    property string query: ""
    property int selected: 0
    property var _wallsBuild: []
    property string currentWall: ""
    property int thumbVersion: 0
    property bool _skipInitialAnim: true
    property bool searching: false
    property bool _extractionRan: false

    property real smoothSelected: 0
    Behavior on smoothSelected {
        enabled: !_skipInitialAnim
        NumberAnimation { duration: _skipInitialAnim ? 0 : 300; easing.type: Easing.OutExpo }
    }

    property string cachePath: Quickshell.env("HOME") + "/.cache/meloworld/wallpaper-thumbs"
    property string wallDir:   Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string imageDirs: Quickshell.env("HOME") + "/Pictures/Wallpapers " + Quickshell.env("HOME") + "/Imagens/Wallpapers"
    property string videoDir:  Quickshell.env("HOME") + "/Vídeos/Wallpapers"

    property real br:     12
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    property real cardW: Math.min(screen ? screen.width * 0.46 : 680, 860)
    property real cardH: Math.round(cardW / 1.6)

    property real angleStep: 38

    // Keep the layer surface alive; this Quickshell/Mango combo can register
    // IPC successfully while a dynamically hidden PanelWindow never becomes
    // visible again. We use conditional visibility to prevent input capture.
    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    // Input is blocked when hidden via visible: showing (line 45).
    // No mask needed — visible:false prevents all input capture.

    property string visibleStatePath: Quickshell.env("HOME") + "/.cache/meloworld/wallpaper-picker-visible"

    FileView {
        path: wallpaper.visibleStatePath
        onLoaded: wallpaper.applyVisibleState(text())
        onTextChanged: wallpaper.applyVisibleState(text())
    }

    Process {
        id: visibleStateReadProc
        command: ["bash", "-lc", "cat \"$1\" 2>/dev/null || printf '0\\n'", "wallpaper-visible-read", wallpaper.visibleStatePath]
        stdout: SplitParser { onRead: data => wallpaper.applyVisibleState(data) }
    }

    Timer {
        // FileView loads the initial value, but on this Quickshell build it is
        // not reliable as an IPC-triggered live watcher. Poll one tiny state
        // file so `qs ipc call wallpaper open` actually drives the picker.
        // Only poll while hidden — once visible, FileView handles live updates.
        interval: 250
        running: !showing
        repeat: true
        onTriggered: {
            visibleStateReadProc.running = false
            visibleStateReadProc.running = true
        }
    }

    Process { id: visibleStateProc }

    function applyVisibleState(raw) {
        var next = String(raw || "").trim() === "1"
        if (showing !== next) showing = next
    }

    function writeVisibleState(next) {
        visibleStateProc.command = ["bash", "-lc",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "wallpaper-visible", visibleStatePath, next ? "1" : "0"]
        visibleStateProc.running = false
        visibleStateProc.running = true
    }

    function showPicker() {
        showing = true
        WallpaperState.visible = true
        writeVisibleState(true)
    }

    function hidePicker() {
        showing = false
        WallpaperState.visible = false
        writeVisibleState(false)
    }

    function togglePicker() {
        if (showing) hidePicker()
        else showPicker()
    }

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function thumbName(path) {
        return String(path || "").replace(/^\/+/, "").replace(/\//g, "_") + ".thumb.jpg"
    }

    function thumbPath(path) {
        return cachePath + "/" + thumbName(path)
    }

    Component.onCompleted: cacheLoadProc.running = true

    onSelectedChanged: smoothSelected = selected

    onShowingChanged: {
        if (showing) {
            query            = ""
            selected         = 0
            smoothSelected   = 0
            keyInput.text    = ""
            _skipInitialAnim = true
            searching        = false
            ready            = false
            currentWallProc.running = true
        } else {
            ready     = false
            searching = false
        }
    }

    Timer {
        id: listReadyDelay
        interval: 50
        onTriggered: {
            ready = true
            enableAnimDelay.start()
            focusDelay.start()
            colorExtractDelay.restart()
        }
    }

    Timer {
        id: focusDelay
        interval: 80
        onTriggered: keyInput.forceActiveFocus()
    }

    Timer {
        id: enableAnimDelay
        interval: 120
        onTriggered: _skipInitialAnim = false
    }

    function filterWalls(preserve) {
        var prevName = preserve && selected < filtered.length ? filtered[selected].name : ""
        var result   = walls.slice()
        if (query !== "") {
            var q = query.toLowerCase()
            result = result.filter(w => w.name.toLowerCase().includes(q))
            result.sort((a, b) => {
                var ai = a.name.toLowerCase().indexOf(q)
                var bi = b.name.toLowerCase().indexOf(q)
                if (ai !== bi) return ai - bi
                return a.name.length - b.name.length
            })
        }
        filtered = result
        if (prevName) {
            for (var i = 0; i < result.length; i++) {
                if (result[i].name === prevName) { selected = i; return }
            }
        }
        selected = 0
    }

    function selectCurrentWall() {
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].name === currentWall) { selected = i; return }
        }
    }

    
    function applyWallpaper(wall) {
        if (!wall) return
        var path = wall.path
        if (wall.isVideo) {
            var tempFrame = cachePath + "/temp_firstframe.jpg"
            applyProc.command = ["bash", "-lc", [
                "set -e",
                "path=$1",
                "temp=$2",
                "lock=\"$HOME/.config/quickshell/lockscreen/wallpaper.png\"",
                "pkill -x awww-daemon 2>/dev/null || true",
                "pkill -x mpvpaper 2>/dev/null || true",
                "mkdir -p \"$HOME/.cache/meloworld\" \"$(dirname \"$lock\")\"",
                "printf 'video:%s\\n' \"$path\" > \"$HOME/.cache/meloworld/last-wallpaper\"",
                "ffmpeg -y -ss 00:00:01 -i \"$path\" -vframes 1 \"$lock\" >/dev/null 2>&1 &",
                "ffmpeg -y -i \"$path\" -ss 00:00:01 -vframes 1 -q:v 2 \"$temp\" 2>/dev/null && " +
                    "awww query >/dev/null 2>&1 || { awww-daemon &>/dev/null & for i in $(seq 1 20); do sleep 0.1 && awww query >/dev/null 2>&1 && break; done; }",
                "awww img \"$temp\" --transition-type wipe --transition-angle 30 --transition-duration 1.5 --transition-fps 60 && sleep 1.5 && " +
                    "mpvpaper -f -p -o '--loop-file=inf --no-audio --hwdec=auto' ALL \"$path\" &"
            ].join("\n"), "wallpaper-apply-video", path, tempFrame]
        } else {
            applyProc.command = ["bash", "-lc", [
                "set -e",
                "path=$1",
                "lock=\"$HOME/.config/quickshell/lockscreen/wallpaper.png\"",
                "pkill -x mpvpaper 2>/dev/null || true",
                "awww query >/dev/null 2>&1 || { awww-daemon &>/dev/null & for i in $(seq 1 20); do sleep 0.1 && awww query >/dev/null 2>&1 && break; done; }",
                "mkdir -p \"$HOME/.cache/meloworld\" \"$(dirname \"$lock\")\"",
                "printf 'image:%s\\n' \"$path\" > \"$HOME/.cache/meloworld/last-wallpaper\"",
                "awww img \"$path\" --transition-type wipe --transition-angle 30 --transition-duration 1.5 --transition-fps 60",
                "cp -f \"$path\" \"$lock\""
            ].join("\n"), "wallpaper-apply-image", path]
        }
        applyProc.running = false
        applyProc.running = true
        currentWall = wall.name

        // Do not rely only on FileView noticing last-wallpaper writes.
        // Trigger Iris immediately so Quickshell colors follow the selected wallpaper.
        IrisColors.loadWallpaperText((wall.isVideo ? "video:" : "image:") + path)
        
        // Hide wallpaper picker on apply
        hidePicker()
    }


    function prettyName(name) {
        var dot = name.lastIndexOf(".")
        var n   = dot > 0 ? name.substring(0, dot) : name
        return n.replace(/[-_]/g, " ")
    }

    function pickRandom() {
        if (filtered.length < 2) return
        var idx = selected
        while (idx === selected)
            idx = Math.floor(Math.random() * filtered.length)
        selected = idx
    }

    
    function writeCache() {
        var arr = []
        for (var i = 0; i < walls.length; i++)
            arr.push({ name: walls[i].name, path: walls[i].path, isVideo: walls[i].isVideo, isGif: walls[i].isGif })
        var json = JSON.stringify(arr)
        writeCacheProc.command = ["bash", "-lc",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/walls.json\"",
            "wallpaper-cache", cachePath, json]
        writeCacheProc.running = false
        writeCacheProc.running = true
    }


    
    Process {
        id: cacheLoadProc
        command: ["cat", cachePath + "/walls.json"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    walls = JSON.parse(data.trim())
                    filtered = walls.slice()
                    thumbVersion = 1
                } catch(e) {}
            }
        }
    }


    
    Process {
        id: currentWallProc
        command: ["bash", "-c", "cat $HOME/.cache/meloworld/last-wallpaper 2>/dev/null | cut -d: -f2 | xargs basename 2>/dev/null"]
        stdout: SplitParser { onRead: data => currentWall = data.trim() }
        onExited: {
            if (walls.length > 0) {
                filterWalls()
                selectCurrentWall()
                listReadyDelay.start()
            }
            _wallsBuild = []
            wallListProc.running = true
        }
    }


    Timer {
        id: colorExtractDelay
        interval: 1500
        onTriggered: colorExtractProc.running = true
    }

    
    Process {
        id: colorExtractProc
        command: ["bash", "-c", [
            "CACHE=\"$HOME/.cache/meloworld/wallpaper-thumbs\"",
            "LOCK=\"$CACHE/.extraction.lock\"",
            "mkdir -p \"$CACHE\"",
            "[ -f \"$LOCK\" ] && exit 0",
            "touch \"$LOCK\"",
            "trap 'rm -f \"$LOCK\"' EXIT",
            "",
            "find \"$HOME/Pictures/Wallpapers\" \"$HOME/Imagens/Wallpapers\" \"$HOME/Vídeos/Wallpapers\" -type f 2>/dev/null | while read -r f; do",
            "  safe=\"${f#/}\"",
            "  safe=\"${safe//\\//_}\"",
            "  thumb=\"$CACHE/${safe}.thumb.jpg\"",
            "  [ -f \"$thumb\" ] && continue",
            "  name=$(basename \"$f\")",
            "  ext=\"${name##*.}\"",
            "  if [[ \"$ext\" =~ ^(mp4|webm|mkv|mov|avi|flv|wmv|ts|m4v|ogv)$ ]]; then",
            "    nice -n 19 ionice -c3 ffmpeg -y -i \"$f\" -ss 00:00:01 -vframes 1 -vf scale=600:-1 \"$thumb\" 2>/dev/null &",
            "  else",
            "    nice -n 19 magick \"${f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null &",
            "  fi",
            "done",
            "wait",
            "echo 'THUMBS_READY'"
        ].join("
")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "THUMBS_READY") thumbVersion++
            }
        }
    }


    Process {
        id: wallListProc
        command: ["bash", "-c", "find \"$HOME/Pictures/Wallpapers\" \"$HOME/Imagens/Wallpapers\" \"$HOME/Vídeos/Wallpapers\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.jxl' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.tga' -o -iname '*.avif' -o -iname '*.pnm' -o -iname '*.svg' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.flv' -o -iname '*.wmv' -o -iname '*.ts' -o -iname '*.m4v' -o -iname '*.ogv' \\) 2>/dev/null | sort -u | jq -R -s -c 'split(\"\\n\")[:-1] | map({name: (split(\"/\") | last), path: ., isVideo: (test(\"\\\\.(mp4|webm|mkv|mov|avi|flv|wmv|ts|m4v|ogv)$\"; \"i\")), isGif: (test(\"\\\\.gif$\"; \"i\"))})'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    walls = JSON.parse(data.trim())
                    filtered = walls.slice()
                    writeCache()
                    filterWalls()
                    selectCurrentWall()
                    listReadyDelay.start()
                } catch(e) {}
            }
        }
    }

    Process { id: applyProc }
    Process { id: writeCacheProc }

    Rectangle {
        anchors.fill: parent
        color: a("#000000", 0.58)
        opacity: ready ? 1 : 0
        enabled: showing
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: showing
        onClicked: hidePicker()
    }

    TextInput {
        id: keyInput
        visible: false
        color: PanelColors.textMain
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
        selectByMouse: true
        readOnly: !searching

        onTextChanged: {
            query = text.toLowerCase()
            filterWalls()
        }

        Keys.onPressed: function(event) {
            if (searching) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    searching = false
                    event.accepted = true
                }
            } else {
                if (event.key === Qt.Key_Slash) {
                    text = ""
                    query = ""
                    searching = true
                    event.accepted = true
                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    if (selected > 0) selected--
                    event.accepted = true
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    if (selected < filtered.length - 1) selected++
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    selected = 0
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    selected = Math.max(0, filtered.length - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    selected = Math.max(0, selected - 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    selected = Math.min(filtered.length - 1, selected + 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (filtered.length > 0) applyWallpaper(filtered[selected])
                    event.accepted = true
                } else if (event.key === Qt.Key_R) {
                    pickRandom()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    if (query !== "") {
                        keyInput.text = ""
                        query = ""
                        filterWalls()
                    } else {
                        hidePicker()
                    }
                    event.accepted = true
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: ready ? 1 : 0
        scale:   ready ? 1 : 0.9
        enabled: showing

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        Item {
            id: sceneRoot
            anchors.centerIn: parent
            width:  parent.width
            height: cardH
            clip:   true

            function slotX(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return parent.width / 2 - cardW / 2 + Math.sin(rad) * (cardW * 0.82)
            }

            function slotAngle(offset) {
                return offset * angleStep
            }

            function slotScale(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return Math.max(0.35, 0.5 + 0.5 * Math.cos(rad))
            }

            function slotOpacity(offset) {
                var dist = Math.abs(offset)
                if (dist < 0.5)  return 1.0
                if (dist < 1.5)  return 1.0  - (dist - 0.5) * 0.25
                if (dist < 2.5)  return 0.75 - (dist - 1.5) * 0.30
                if (dist < 3.0)  return 0.45 * (3.0 - dist) / 0.5
                return 0.0
            }

            
            function thumbSource(idx) {
                if (idx < 0 || idx >= filtered.length) return ""
                if (thumbVersion > 0)
                    return "file://" + thumbPath(filtered[idx].path)
                return "file://" + filtered[idx].path
            }


            Repeater {
                model: filtered

                Item {
                    id: slotItem
                    required property int index
                    required property var modelData

                    property real offset:    index - smoothSelected
                    property real absOffset: Math.abs(offset)
                    property bool isCenter:  index === selected

                    width:  cardW
                    height: cardH
                    x:      sceneRoot.slotX(offset)
                    y:      0
                    scale:  sceneRoot.slotScale(offset)
                    opacity: sceneRoot.slotOpacity(offset)
                    visible: absOffset < 3.0
                    z:      isCenter ? 999 : Math.round((1.0 - Math.min(absOffset, 2.0) / 2.0) * 100)

                    transform: Rotation {
                        origin.x: cardW / 2
                        origin.y: cardH / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: sceneRoot.slotAngle(slotItem.offset)
                    }

                    Rectangle {
                        id: slotRect
                        anchors.fill: parent
                        radius: br
                        color:  "#000"
                        clip:   true

                        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        property bool isGif:   slotItem.isCenter && modelData.isGif
                        property bool isVideo: slotItem.isCenter && modelData.isVideo

                        Image {
                            anchors.fill: parent
                            source: slotItem.isCenter && !slotRect.isGif && !slotRect.isVideo
                                ? (thumbVersion > 0
                                    ? "file://" + thumbPath(slotItem.modelData.path)
                                    : "file://" + slotItem.modelData.path)
                                : (!slotItem.isCenter
                                    ? sceneRoot.thumbSource(slotItem.index)
                                    : "")
                            onStatusChanged: {
                                if (status === Image.Error && slotItem.isCenter)
                                    source = "file://" + slotItem.modelData.path
                            }
                            fillMode: slotItem.isCenter ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize.width: slotItem.isCenter ? 1920 : 400
                            asynchronous: true
                            cache: true
                            visible: !slotRect.isGif && !slotRect.isVideo
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isGif
                            sourceComponent: AnimatedImage {
                                anchors.fill: parent
                                source: "file://" + slotItem.modelData.path
                                fillMode: Image.PreserveAspectFit
                                playing: true
                                asynchronous: true
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isVideo
                            sourceComponent: Item {
                                anchors.fill: parent
                                MediaPlayer {
                                    id: slotVid
                                    source: "file://" + slotItem.modelData.path
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: slotVidOut
                                    Component.onCompleted: play()
                                }
                                VideoOutput {
                                    id: slotVidOut
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: slotItem.isCenter ? "transparent" : a("#000", 0.35)
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Item {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 56
                            visible: slotItem.isCenter
                            opacity: slotItem.isCenter ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: a("#000", 0.72) }
                                }
                            }

                            Row {
                                anchors { left: parent.left; bottom: parent.bottom }
                                anchors { leftMargin: 18; bottomMargin: 14 }
                                spacing: 10

                                Text {
                                    text:  prettyName(slotItem.modelData.name)
                                    color: "#fff"
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: slotItem.modelData.name === currentWall
                                    text:    "●"
                                    color:   PanelColors.green
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: br
                            color:  "transparent"
                            border.width: slotItem.isCenter ? 2 : slotItem.modelData.name === currentWall ? 1.5 : 0
                            border.color: slotItem.modelData.name === currentWall ? PanelColors.green : PanelColors.launcher
                            Behavior on border.color { ColorAnimation  { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on radius       { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: slotItem.isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (slotItem.isCenter) applyWallpaper(slotItem.modelData)
                            else selected = slotItem.index
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                z: -999
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                        if (selected > 0) selected--
                    } else {
                        if (selected < filtered.length - 1) selected++
                    }
                }
            }
        }

        Rectangle {
            id: emptyCard
            anchors.centerIn: sceneRoot
            width:  cardW
            height: cardH
            radius: br
            color:  a(PanelColors.popupBackground, 0.92)
            border.width: 1
            border.color: a(PanelColors.textMain, 0.06)
            visible: ready && filtered.length === 0
            opacity: visible ? 1 : 0
            scale:   visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 300;   easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            Behavior on radius  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color   { ColorAnimation  { duration: 300 } }

            Column {
                anchors.centerIn: parent
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  walls.length === 0 ? "󰏗" : "󰍉"
                    color: a(PanelColors.textMain, 0.1)
                    font { pixelSize: 48; family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  walls.length === 0 ? "Scanning wallpapers" : "No results"
                        color: a(PanelColors.textMain, 0.4)
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: query !== ""
                        text:    "\"" + query + "\""
                        color:   a(PanelColors.textMain, 0.2)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: filtered.length === 0 && query !== ""

                    Text {
                        text: "Press"
                        color: a(PanelColors.textMain, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width:  escLbl.width + 14
                        height: 20
                        radius: brSm
                        color:  a(PanelColors.textMain, 0.05)
                        border.width: 1
                        border.color: a(PanelColors.textMain, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: escLbl
                            anchors.centerIn: parent
                            text:  "Esc"
                            color: a(PanelColors.textMain, 0.3)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Text {
                        text: "to clear"
                        color: a(PanelColors.textMain, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            id: searchBar
            anchors {
                top:              sceneRoot.bottom
                topMargin:        24
                horizontalCenter: parent.horizontalCenter
            }
            width:  200
            height: 34
            radius: brSm
            color:  a(PanelColors.popupBackground, 0.35)
            border.width: 1
            border.color: searching ? a(PanelColors.launcher, 0.3) : a(PanelColors.textMain, 0.05)
            opacity: ready ? 1 : 0
            scale:   ready ? 1 : 0.95

            Behavior on border.color { ColorAnimation  { duration: 150 } }
            Behavior on radius       { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale        { NumberAnimation { duration: 300;   easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin:  11
                anchors.rightMargin: 11
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  ""
                    color: searching ? PanelColors.launcher : a(PanelColors.textMain, 0.3)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyInput.text || (searching ? "" : "/ search")
                    color: keyInput.text ? PanelColors.textMain : a(PanelColors.textMain, 0.25)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:    "󰅖"
                    color:   clrMa.containsMouse ? PanelColors.textMain : a(PanelColors.textMain, 0.3)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    visible: keyInput.text.length > 0
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { keyInput.text = ""; keyInput.forceActiveFocus() }
                    }
                }
            }

            MouseArea {
                id: searchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (!searching) { searching = true; keyInput.text = ""; query = "" }
                    keyInput.forceActiveFocus()
                }
            }
        }
    }
}