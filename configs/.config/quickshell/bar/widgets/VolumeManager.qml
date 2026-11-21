import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int volume: 0
    property bool muted: false
    property bool initialized: false

    signal adjusted()

    // Один процесс: слушает события и выводит громкость только при изменениях
    Process {
        id: volumeMonitor
        running: true
        command: ["sh", "-c", "pactl subscribe 2>/dev/null | while IFS= read -r line; do case \"$line\" in *\"'change' on sink\"*) LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null ;; esac; done"]

        stdout: SplitParser {
            onRead: function(line) {

                var match = /Volume:\s*([0-9.]+)/.exec(line)
                if (!match) return

                var newVolume = Math.round(parseFloat(match[1]) * 100)
                if (isNaN(newVolume)) return
                newVolume = Math.max(0, Math.min(100, newVolume))

                var newMuted = line.indexOf("[MUTED]") !== -1

                if (!root.initialized) {
                    root.initialized = true
                    root.volume = newVolume
                    root.muted = newMuted
                    return
                }

                if (newVolume !== root.volume || newMuted !== root.muted) {
                    root.volume = newVolume
                    root.muted = newMuted
                    root.adjusted()
                }
            }
        }
    }

    // Начальное чтение при старте
    Process {
        id: initialRead
        running: true
        command: ["sh", "-c", "LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                var match = /Volume:\s*([0-9.]+)/.exec(text)
                if (!match) return

                var vol = Math.round(parseFloat(match[1]) * 100)
                if (isNaN(vol)) return

                root.initialized = true
                root.volume = Math.max(0, Math.min(100, vol))
                root.muted = text.indexOf("[MUTED]") !== -1
            }
        }
    }

    function setVolume(percent) {
        var value = Math.max(0, Math.min(100, Math.round(percent)))
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", value + "%"])
    }

    function changeVolume(delta) {
        var value = Math.max(0, Math.min(100, root.volume + delta))
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", value + "%"])
    }

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    }
}
