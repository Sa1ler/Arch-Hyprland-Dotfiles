import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    //  ЗАВИСИМОСТИ И НАСТРОЙКИ
    // ============================================================

    // SettingsManager: читаем settings.soundEffects и settings.soundVolume.
    // Менеджер ничего не пишет в настройки.
    property var settingsManager: null

    // Звуки, которые грузятся в память заранее (минимальная задержка первого воспроизведения).
    // Остальные грузятся при первом использовании. Предзагрузка идёт только при включённых эффектах.
    property var preload: ["click.wav", "click2.wav", "quick_click.wav", "tick.wav",
                           "in.wav", "out.wav", "switch.wav", "swoosh.wav"]

    // Защита от спама: один и тот же звук не чаще, чем раз в N мс
    property int minIntervalMs: 30
    // Лимит одновременных процессов в запасном режиме
    property int maxFallbackProcesses: 4
    // Плеер для запасного режима
    property string fallbackPlayer: "pw-play"

    // ============================================================
    //  ПУТИ И ПРАВИЛА
    // ============================================================

    readonly property string soundsDir: root.cleanPath(Quickshell.shellDir + "/../assets/sounds")

    // Только безопасные имена: запрещает "../x", пути, пробелы и прочее
    readonly property var namePattern: /^[A-Za-z0-9_-]{1,64}$/

    readonly property int _statusError: 3     // SoundEffect.Error
    readonly property int _maxWarnings: 64    // предел запоминаемых предупреждений

    // ============================================================
    //  СОСТОЯНИЕ
    // ============================================================

    readonly property bool _hasSettings: root.settingsManager !== null && root.settingsManager !== undefined

    // Пока настройки не загрузились, молчим: иначе звук мог бы сыграть при выключенных эффектах
    readonly property bool soundsEnabled: root._hasSettings
        ? (root.settingsManager.isReady && root.settingsManager.general.soundEffects !== false)
        : true

    // 0..1. Если ключа soundVolume в схеме нет, громкость 100%.
    readonly property real masterVolume: {
        if (!root._hasSettings || !root.settingsManager.isReady)
            return 1.0
        var v = root.settingsManager.general.soundVolume
        return typeof v === "number" && isFinite(v) ? Math.max(0, Math.min(1, v / 100)) : 1.0
    }

    // "effect" (QtMultimedia SoundEffect) или "process" (запасной: pw-play)
    property string backend: "none"

    // Список доступных звуков без расширения (для UI, например выбора звука в настройках)
    property var names: []

    property var _factory: null       // QtObject с готовым (один раз скомпилированным) Component SoundEffect
    property var _available: ({})
    property bool _scanned: false
    property bool _preloaded: false
    property bool _preloading: false
    property var _preloadQueue: []
    property var _effects: ({})       // stem -> SoundEffect
    property var _loops: ({})         // stem -> gain (>0), пока звук играет зацикленно
    property var _lastPlayed: ({})    // stem -> timestamp
    property var _warned: ({})
    property int _warnedCount: 0
    property var _procs: []
    property int _procCount: 0

    onSoundsEnabledChanged: {
        if (root.soundsEnabled) {
            root.startPreload()
        } else {
            // Эффекты выключены: останавливаем звук и освобождаем память
            root.stopAll()
            root.releaseEffects()
        }
    }

    // Громкость нужно обновлять только у играющих циклов. Остальным она
    // выставляется при каждом play(), поэтому проходить по всем эффектам не нужно.
    onMasterVolumeChanged: {
        var keys = Object.keys(root._loops)
        for (var i = 0; i < keys.length; i++) {
            var e = root._effects[keys[i]]
            if (e)
                e.volume = Math.max(0, Math.min(1, root.masterVolume * root._loops[keys[i]]))
        }
    }

    Component.onCompleted: root.probeBackend()
    Component.onDestruction: root.stopAll()

    // ============================================================
    //  СКАНИРОВАНИЕ ПАПКИ
    // ============================================================

    FolderListModel {
        id: soundFolder
        folder: "file://" + root.soundsDir
        nameFilters: ["*.wav"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                rescan.restart()
        }
        onCountChanged: rescan.restart()
    }

    Timer {
        id: rescan
        interval: 40
        onTriggered: root.rebuildAvailable()
    }

    // Предзагрузка по одному звуку за тик, чтобы не было пика нагрузки на старте.
    // Таймер работает только пока очередь не пуста.
    Timer {
        id: preloadTimer
        interval: 30
        repeat: true
        running: root._preloading
        onTriggered: {
            var q = root._preloadQueue
            if (q.length === 0) {
                root._preloading = false
                return
            }
            root.getEffect(q.shift())
            if (q.length === 0)
                root._preloading = false
        }
    }

    // ============================================================
    //  ПУБЛИЧНЫЙ API
    // ============================================================

    // Проиграть звук один раз. name: "click.wav" или "click".
    // gain: множитель громкости 0..1 для конкретного звука (необязательно).
    // Возвращает true, если воспроизведение запущено.
    function play(name, gain) {
        var stem = root.prepare(name)
        if (stem === "")
            return false

        if (root._loops[stem])
            return false     // не сбиваем зацикленный звук

        var now = Date.now()
        if (now - (root._lastPlayed[stem] || 0) < root.minIntervalMs)
            return false
        root._lastPlayed[stem] = now

        var vol = root.effectiveVolume(gain)
        if (vol <= 0)
            return false

        if (root.backend === "effect") {
            var e = root.getEffect(stem)
            if (!e)
                return false
            e.loops = 1
            e.volume = vol
            e.play()
            return true
        }
        return root.playProcess(stem, vol)
    }

    // Зацикленное воспроизведение (например, charge_loop2). Только в режиме "effect".
    function playLoop(name, gain) {
        var stem = root.prepare(name)
        if (stem === "")
            return false
        if (root.backend !== "effect") {
            root.warnOnce("loop", "зацикленные звуки требуют QtMultimedia")
            return false
        }
        if (root._loops[stem])
            return true

        var vol = root.effectiveVolume(gain)
        if (vol <= 0)
            return false
        var e = root.getEffect(stem)
        if (!e)
            return false
        e.loops = -2                 // SoundEffect.Infinite
        e.volume = vol
        e.play()
        root._loops[stem] = root.normalizeGain(gain)
        return true
    }

    function stop(name) {
        var stem = root.normalize(name)
        if (stem === "")
            return
        delete root._loops[stem]
        var e = root._effects[stem]
        if (e) {
            e.stop()
            e.loops = 1
        }
    }

    function stopAll() {
        var keys = Object.keys(root._effects)
        for (var i = 0; i < keys.length; i++) {
            root._effects[keys[i]].stop()
            root._effects[keys[i]].loops = 1
        }
        root._loops = ({})
        root.pruneProcs(true)
    }

    function has(name) {
        var stem = root.normalize(name)
        return stem !== "" && (!root._scanned || root._available[stem] === true)
    }

    // ============================================================
    //  ВНУТРЕННЯЯ ЛОГИКА
    // ============================================================

    // Все проверки перед воспроизведением. Возвращает безопасное имя или "".
    function prepare(name) {
        if (!root.soundsEnabled)
            return ""
        var stem = root.normalize(name)
        if (stem === "") {
            root.warnOnce("bad:" + name, "недопустимое имя звука: " + name)
            return ""
        }
        // Пока папка не просканирована, наличие файла не проверяем (старт шелла)
        if (root._scanned && root._available[stem] !== true) {
            root.warnOnce("missing:" + stem, "звук не найден: " + stem + ".wav")
            return ""
        }
        return stem
    }

    function normalize(name) {
        if (typeof name !== "string")
            return ""
        var n = name.trim()
        if (n.length > 4 && n.slice(-4).toLowerCase() === ".wav")
            n = n.slice(0, -4)
        return root.namePattern.test(n) ? n : ""
    }

    function normalizeGain(gain) {
        var g = gain === undefined || gain === null ? 1.0 : Number(gain)
        return isFinite(g) ? g : 1.0
    }

    function effectiveVolume(gain) {
        return Math.max(0, Math.min(1, root.masterVolume * root.normalizeGain(gain)))
    }

    function filePath(stem) {
        return root.soundsDir + "/" + stem + ".wav"
    }

    // ---------- выбор бэкенда ----------

    // QtMultimedia подключается динамически: если модуля нет, шелл всё равно запустится.
    // QML компилируется один раз, дальше эффекты создаются дёшево через createObject.
    function probeBackend() {
        try {
            root._factory = Qt.createQmlObject(
                'import QtQuick\nimport QtMultimedia\n'
                + 'QtObject { property Component effect: Component { SoundEffect { } } }',
                root, "SoundFactory")
            root.backend = "effect"
        } catch (e) {
            console.warn("[SoundManager] QtMultimedia недоступен, использую", root.fallbackPlayer)
            root.backend = "process"
        }
        root.startPreload()
    }

    // ---------- режим "effect" ----------

    function getEffect(stem) {
        var cached = root._effects[stem]
        if (cached) {
            if (cached.status === root._statusError) {
                cached.destroy()
                delete root._effects[stem]
                delete root._loops[stem]
                return null
            }
            return cached
        }
        if (!root._factory)
            return null

        var e = root._factory.effect.createObject(root, {
            "source": "file://" + root.filePath(stem),
            "volume": root.masterVolume
        })
        if (!e) {
            console.warn("[SoundManager] не удалось создать SoundEffect:", stem)
            return null
        }

        e.statusChanged.connect(function () {
            if (e.status === root._statusError) {
                console.warn("[SoundManager] ошибка загрузки звука:", stem)
                // Не трогаем запись, если за это время создан новый эффект с тем же именем
                if (root._effects[stem] === e) {
                    delete root._effects[stem]
                    delete root._loops[stem]
                }
                e.destroy()
            }
        })
        root._effects[stem] = e
        return e
    }

    // Предзагрузка: только когда папка просканирована, эффекты включены и доступен QtMultimedia
    function startPreload() {
        if (root._preloaded || !root._scanned || !root.soundsEnabled || root.backend !== "effect")
            return
        root._preloaded = true
        var q = []
        for (var i = 0; i < root.preload.length; i++) {
            var s = root.normalize(root.preload[i])
            if (s !== "" && root._available[s] === true && !root._effects[s])
                q.push(s)
        }
        root._preloadQueue = q
        root._preloading = q.length > 0
    }

    // Освобождает все загруженные эффекты (при выключении звуков)
    function releaseEffects() {
        root._preloading = false
        root._preloadQueue = []
        root._preloaded = false
        var keys = Object.keys(root._effects)
        for (var i = 0; i < keys.length; i++)
            root._effects[keys[i]].destroy()
        root._effects = ({})
        root._loops = ({})
    }

    // ---------- запасной режим "process" ----------

    // Процесс сам удаляется сразу после завершения, поэтому опрашивающий таймер не нужен
    Component {
        id: procComp
        Process {
            id: proc
            onRunningChanged: {
                if (!proc.running)
                    root.reapProc(proc)
            }
        }
    }

    function playProcess(stem, vol) {
        root.pruneProcs(false)     // страховка, если какой-то процесс не сообщил о завершении
        if (root._procCount >= root.maxFallbackProcesses)
            return false
        var p = procComp.createObject(root, {
            "command": [root.fallbackPlayer, "--volume=" + vol.toFixed(2), root.filePath(stem)],
            "running": true
        })
        if (!p)
            return false
        root._procs.push(p)
        root._procCount = root._procs.length
        return true
    }

    function reapProc(p) {
        var i = root._procs.indexOf(p)
        if (i >= 0) {
            root._procs.splice(i, 1)
            root._procCount = root._procs.length
        }
        p.destroy()
    }

    // Удаляет завершившиеся процессы; force завершает все
    function pruneProcs(force) {
        var alive = []
        for (var i = 0; i < root._procs.length; i++) {
            var p = root._procs[i]
            if (!p)
                continue
            if (force || !p.running)
                p.destroy()
            else
                alive.push(p)
        }
        root._procs = alive
        root._procCount = alive.length
    }

    // ---------- список доступных звуков ----------

    function rebuildAvailable() {
        var map = ({})
        var list = []
        for (var i = 0; i < soundFolder.count; i++) {
            var f = soundFolder.get(i, "fileName")
            if (typeof f !== "string" || f.length < 5 || f.slice(-4).toLowerCase() !== ".wav")
                continue
            var stem = f.slice(0, -4)
            if (!root.namePattern.test(stem))
                continue
            map[stem] = true
            list.push(stem)
        }
        var scanned = soundFolder.status === FolderListModel.Ready

        // Не пересоздаём список, если он не изменился: подписанный UI не перестраивается зря
        if (!root.sameNames(list, root.names)) {
            root._available = map
            root.names = list

            // Удаляем кэш звуков, файлы которых пропали. Только после полного сканирования,
            // иначе пустая модель на старте убила бы уже созданные эффекты.
            if (scanned) {
                var keys = Object.keys(root._effects)
                for (var j = 0; j < keys.length; j++) {
                    if (!map[keys[j]]) {
                        root._effects[keys[j]].destroy()
                        delete root._effects[keys[j]]
                        delete root._loops[keys[j]]
                    }
                }
            }
        }
        root._scanned = scanned

        root.startPreload()
    }

    // ---------- утилиты ----------

    function sameNames(a, b) {
        if (a === b)
            return true
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    // Каждое предупреждение выводится один раз, а запоминается не больше _maxWarnings
    // ключей: имена приходят снаружи, и словарь не должен расти бесконечно.
    function warnOnce(key, msg) {
        if (root._warned[key] || root._warnedCount >= root._maxWarnings)
            return
        root._warned[key] = true
        root._warnedCount++
        console.warn("[SoundManager]", msg)
    }

    // Нормализует путь: убирает "/../" и "/./", чтобы URL файла был чистым
    function cleanPath(p) {
        var out = []
        var parts = String(p).split("/")
        for (var i = 0; i < parts.length; i++) {
            var s = parts[i]
            if (s === "" || s === ".")
                continue
            if (s === "..")
                out.pop()
            else
                out.push(s)
        }
        return "/" + out.join("/")
    }
}