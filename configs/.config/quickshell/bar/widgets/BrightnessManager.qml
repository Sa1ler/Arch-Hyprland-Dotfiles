import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int brightness: 0
    property bool initialized: false

    signal adjusted()

    // Читаем актуальное значение один раз при старте
    Process {
        id: initialRead
        running: true
        command: ["sh", "-c", "b=$(cat /sys/class/backlight/intel_backlight/brightness 2>/dev/null); m=$(cat /sys/class/backlight/intel_backlight/max_brightness 2>/dev/null); printf '%s %s' \"$b\" \"$m\""]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                if (parts.length < 2) return

                var current = parseInt(parts[0])
                var max = parseInt(parts[1])
                if (isNaN(current) || isNaN(max) || max <= 0) return

                root.brightness = Math.max(0, Math.min(100, Math.round(current / max * 100)))
                root.initialized = true
            }
        }
    }

    // Событийный мониторинг: спит в ядре, будится ТОЛЬКО при изменении
    Process {
        id: brightnessEvents
        running: true
        command: ["sh", "-c",
            "stdbuf -oL udevadm monitor --kernel --subsystem-match=backlight 2>/dev/null | while IFS= read -r line; do " +
            "case \"$line\" in " +
            "*backlight*) " +
            "b=$(cat /sys/class/backlight/intel_backlight/brightness 2>/dev/null); " +
            "m=$(cat /sys/class/backlight/intel_backlight/max_brightness 2>/dev/null); " +
            "if [ -n \"$b\" ] && [ -n \"$m\" ]; then printf '%s %s\\n' \"$b\" \"$m\"; fi ;; " +
            "esac; done"]

        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(/\s+/)
                if (parts.length < 2) return

                var current = parseInt(parts[0])
                var max = parseInt(parts[1])
                if (isNaN(current) || isNaN(max) || max <= 0) return

                var percent = Math.max(0, Math.min(100, Math.round(current / max * 100)))

                // Никакого спама: реагируем только на РЕАЛЬНОЕ изменение
                if (!root.initialized) {
                    root.initialized = true
                    root.brightness = percent
                    return
                }

                if (percent !== root.brightness) {
                    root.brightness = percent
                    root.adjusted()
                }
            }
        }
    }

    function setBrightness(percent) {
        var value = Math.max(0, Math.min(100, Math.round(percent)))
        Quickshell.execDetached(["brightnessctl", "set", value + "%"])
    }

    function changeBrightness(delta) {
        var value = Math.max(0, Math.min(100, root.brightness + delta))
        Quickshell.execDetached(["brightnessctl", "set", value + "%"])
    }
}