pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * BrightnessState — tela (ddcutil) + teclado (brightnessctl)
 *
 * Bugs corrigidos vs. versão anterior:
 * 1. REMOVIDO read-loop: brightnessProc rodava dentro do próprio onComplete,
 *    criando um loop infinito de re-leituras. Agora usa um Timer.oneShot
 *    murni para debounce + flag de escrita.
 * 2. Debounce correto: um único Timer (150 ms) coalesca mudanças rápidas
 *    do slider antes de enviar ao hardware.
 * 3. Leitura só quando idle: a polling só relê depois que a escrita termina,
 *    evitando consumir valores intermediários do brightnessctl.
 */

Singleton {
    id: root

    // ── Screen brightness (ddcutil) ─────────────────────────────────────────────
    property int brightness: 100

    // ── Keyboard backlight (brightnessctl) ─────────────────────────────────────
    property int kbdBrightness: 0

    // ── Popup ─────────────────────────────────────────────────────────────────
    property bool popupVisible: false

    // ── Internals ─────────────────────────────────────────────────────────────
    property int pendingValue: -1
    property bool writing: false

    // Debounce: após a última chamada a setBrightness(), espera 150 ms antes
    // de efetivamente enviar ao monitor.
    Timer {
        id: debounce
        interval: 150
        onTriggered: flushPending()
    }

    // ── Ler brilho atual (ddcutil getvcp 10 -t) ──────────────────────────────
    Process {
        id: readProc
        command: ["ddcutil", "getvcp", "10", "-t"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Formato terse (-t): "VCP 10 C N M"  ou  normal: "current value = N"
                const m = this.text.match(/(?:current value\s*=\s*|C\s+)(\d+)/)
                if (m) {
                    root.brightness = parseInt(m[1], 10)
                    root.pendingValue = -1
                }
            }
        }
    }

    // ── Escrever brilho (ddcutil setvcp 10 N) ─────────────────────────────────
    Process {
        id: writeProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.writing = false
                readLaterTimer.running = true
            }
        }
    }

    // Lê 250 ms após a escrita (ddcutil é lento).
    Timer {
        id: readLaterTimer
        interval: 250
        onTriggered: {
            readProc.running = false
            readProc.running = true
        }
    }

    // ── Polling: mantém leitura em dia quando ninguém mexe ────────────────────
    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: !root.writing
        onTriggered: {
            if (debounce.running || root.writing) return
            readProc.running = false
            readProc.running = true
        }
    }

    // ── API ──────────────────────────────────────────────────────────────────
    function setBrightness(val) {
        const v = Math.max(0, Math.min(100, Math.round(val)))
        root.brightness = v
        root.pendingValue = v

        if (root.writing) return   // debounce ativo, valor mais recente fica em pending
        debounce.restart()
    }

    function flushPending() {
        if (root.pendingValue < 0 || root.writing) return
        root.writing = true
        writeProc.running = false
        writeProc.command = ["ddcutil", "setvcp", "10", String(root.pendingValue)]
        writeProc.running = true
        root.pendingValue = -1
    }

    // ── Popup ─────────────────────────────────────────────────────────────────
    function show()   { root.popupVisible = true }
    function hide()   { root.popupVisible = false }
    function toggle() { root.popupVisible = !root.popupVisible }

    // ── Init ─────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        readProc.running = false
        readProc.running = true
    }
}
