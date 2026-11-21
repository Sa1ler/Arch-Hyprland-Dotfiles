import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    //  КОНСТАНТЫ И СХЕМА
    // ============================================================

    readonly property int maxFileBytes: 1048576
    readonly property int maxStringLength: 4096
    readonly property int maxKeyLength: 128
    readonly property int maxUsageEntries: 500
    readonly property int saveDelayMs: 150
    readonly property int reloadDelayMs: 30

    readonly property string settingsPath: {
        var home = Quickshell.env("HOME")
        if (home && home.length > 0)
            return home + "/.config/quickshell/settings.json"
        return Quickshell.shellDir + "/../settings.json"
    }

    readonly property var defaults: ({
        "theme": { "current": "default" },
        "launcher": {
            "maxResults": 20,
            "searchDebounce": 100,
            "showIcons": true,
            "usageRanks": {}
        },
        "island": {
            "enabled": true,
            "height": 34,
            "indicators": {
                "battery": true,
                "clock": true,
                "network": true,
                "workspaces": true
            },
            "length": 220,
            "margin": 4,
            "shape": "notch"
        },
        "settings": {
            "animations": true,
            "soundEffects": true,
            "soundVolume": 100
        },
        "notifications": {
            "dnd": false
        },
        "display": {
            "nightMode": false
        }
    })

    readonly property var numberBounds: ({
        "island.height":           [16, 200],
        "island.length":           [60, 4000],
        "island.margin":           [0, 200],
        "launcher.maxResults":     [1, 100],
        "launcher.searchDebounce": [0, 5000],
        "settings.soundVolume":    [0, 100]
    })

    readonly property var allowedStrings: ({
        "island.shape": ["notch", "pill", "capsule", "circle"]
    })

    readonly property var stringPatterns: ({
        "theme.current": /^[A-Za-z0-9_-]{1,64}$/
    })

    readonly property var freeDictPaths: ({
        "launcher.usageRanks": true
    })

    // ============================================================
    //  СОСТОЯНИЕ
    // ============================================================

    // Главное дерево настроек. Нужно для сериализации и get()/set().
    // UI-коду лучше биндиться на секции ниже, а не на это свойство.
    property var settings: ({})
    property bool ready: false

    property var _theme
    property var _launcher
    property var _island
    property var _general
    property var _notifications
    property var _display
    property var _usageRanks: ({})
    property string _currentTheme: "default"

    // Пока секция не заполнена из файла, отдаём дефолты: undefined не вернётся никогда
    readonly property bool   isReady:       root.ready
    readonly property var    themeSection:  root._theme         !== undefined ? root._theme         : root.defaults.theme
    readonly property var    launcher:      root._launcher      !== undefined ? root._launcher      : root.defaults.launcher
    readonly property var    island:        root._island        !== undefined ? root._island        : root.defaults.island
    readonly property var    general:       root._general       !== undefined ? root._general       : root.defaults.settings
    readonly property var    notifications: root._notifications !== undefined ? root._notifications : root.defaults.notifications
    readonly property var    display:       root._display       !== undefined ? root._display       : root.defaults.display
    readonly property var    usageRanks:    root._usageRanks
    readonly property string currentTheme:  root._currentTheme

    // Точечный сигнал локального изменения: путь вида "island.height"
    signal keyChanged(string path)
    // Сигнал изменения секции (локального или из файла)
    signal sectionChanged(string name)

    // Последний известный текст файла на диске: то, что мы записали или прочитали.
    // По нему отсекаются эхо собственной записи и повторные события с тем же содержимым.
    property string _diskText: ""
    property bool _noWrite: false
    property bool _constructed: false
    property bool _hasPendingError: false
    property var _pendingError: null

    // Любое присвоение settings (set, загрузка из файла, reset) раздаётся по секциям
    onSettingsChanged: root.syncSections()

    // ============================================================
    //  ФАЙЛОВЫЙ СЛОЙ
    // ============================================================

    FileView {
        id: settingsFile
        path: root.settingsPath
        // Запись синхронная намеренно: flush() при завершении шелла должен
        // гарантированно успеть записать файл до выхода процесса
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false

        // Серия inotify-событий (атомарная запись, редакторы) даёт одно чтение
        onFileChanged: reloadTimer.restart()
        onLoaded: root.loadFromDisk()
        onLoadFailed: error => root.handleLoadFailed(error)
    }

    FileView {
        id: backupFile
        path: root.settingsPath + ".bak"
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }

    Timer {
        id: reloadTimer
        interval: root.reloadDelayMs
        onTriggered: settingsFile.reload()
    }

    Timer {
        id: saveTimer
        interval: root.saveDelayMs
        onTriggered: root.writeToDisk()
    }

    // Страховка на случай, если файл не ответил. Работает только пока настройки
    // не готовы: при нормальном старте таймер вообще не срабатывает.
    Timer {
        id: initGuard
        interval: 1500
        running: !root.ready
        onTriggered: {
            if (!root.ready) {
                console.warn("[SettingsManager] файл не ответил, работаю с дефолтами без записи")
                root._noWrite = true
                root.settings = root.deepCopy(root.defaults)
                root.ready = true
            }
        }
    }

    Component.onCompleted: {
        root._constructed = true
        // Файл мог загрузиться, пока объект ещё создавался: обрабатываем сейчас
        if (settingsFile.loaded)
            root.loadFromDisk()
        else if (root._hasPendingError)
            root.handleLoadFailed(root._pendingError)
    }
    Component.onDestruction: root.flush()

    // ============================================================
    //  РАЗДАЧА ПО СЕКЦИЯМ
    // ============================================================

    function sameValue(a, b) {
        return a === b || deepEqual(a, b)
    }

    function syncSections() {
        var s = root.settings
        if (!isObject(s))
            return

        if (s.theme !== undefined && !sameValue(root._theme, s.theme)) {
            root._theme = s.theme
            root.sectionChanged("theme")
        }
        if (s.launcher !== undefined && !sameValue(root._launcher, s.launcher)) {
            root._launcher = s.launcher
            root.sectionChanged("launcher")
        }
        if (s.island !== undefined && !sameValue(root._island, s.island)) {
            root._island = s.island
            root.sectionChanged("island")
        }
        if (s.settings !== undefined && !sameValue(root._general, s.settings)) {
            root._general = s.settings
            root.sectionChanged("settings")
        }
        if (s.notifications !== undefined && !sameValue(root._notifications, s.notifications)) {
            root._notifications = s.notifications
            root.sectionChanged("notifications")
        }
        if (s.display !== undefined && !sameValue(root._display, s.display)) {
            root._display = s.display
            root.sectionChanged("display")
        }

        var ranks = isObject(s.launcher) && isObject(s.launcher.usageRanks) ? s.launcher.usageRanks : ({})
        if (!sameValue(root._usageRanks, ranks))
            root._usageRanks = ranks

        var cur = isObject(s.theme) && typeof s.theme.current === "string" ? s.theme.current : "default"
        if (root._currentTheme !== cur)
            root._currentTheme = cur
    }

    // ============================================================
    //  ПУБЛИЧНЫЙ API
    // ============================================================

    // path: "island.height" или массив ["launcher","usageRanks","org.gnome.Nautilus"]
    function get(path, fallback) {
        var parts = splitPath(path)
        return parts ? getParts(parts, fallback) : fallback
    }

    function set(path, value) {
        var parts = splitPath(path)
        if (!parts) {
            console.warn("[SettingsManager] недопустимый путь:", path)
            return false
        }
        return setParts(parts, value)
    }

    function getSection(name) {
        if (isObject(root.settings) && hasOwn(root.settings, name))
            return root.settings[name]
        return hasOwn(root.defaults, name) ? deepCopy(root.defaults[name]) : ({})
    }

    function updateSection(name, obj) {
        if (!isSafeKey(name) || !hasOwn(root.defaults, name)) {
            console.warn("[SettingsManager] неизвестная секция:", name)
            return false
        }
        return commit([name], validateNode(obj, root.defaults[name], name))
    }

    function reset() {
        root.settings = deepCopy(root.defaults)
        scheduleSave()
    }

    function flush() {
        if (saveTimer.running)
            writeToDisk()
    }

    function setCurrentTheme(name) {
        root.set("theme.current", String(name))
    }

    function bumpAppUsage(appName) {
        var name = String(appName === undefined || appName === null ? "" : appName)
        if (!isSafeKey(name))
            return
        var cur = root._usageRanks[name]
        setParts(["launcher", "usageRanks", name], (typeof cur === "number" ? cur : 0) + 1)
    }

    // ============================================================
    //  ЗАПИСЬ ЗНАЧЕНИЙ
    // ============================================================

    // Чтение по уже проверенным частям пути (без повторной валидации ключей)
    function getParts(parts, fallback) {
        var node = root.settings
        for (var i = 0; i < parts.length; i++) {
            if (!isObject(node) || !hasOwn(node, parts[i]))
                return fallback
            node = node[parts[i]]
        }
        return node === undefined ? fallback : node
    }

    function setParts(parts, value) {
        var info = resolveSchema(parts)

        if (info.kind === "schema")
            return commit(parts, validateNode(value, info.def, parts.join(".")))

        if (info.kind === "free") {
            if (parts.length !== info.index + 1) {
                console.warn("[SettingsManager] вложенность в свободный словарь запрещена:", parts.join("."))
                return false
            }
            var rank = sanitizeRank(value)
            if (rank === undefined) {
                console.warn("[SettingsManager] недопустимое значение для", parts.join("."))
                return false
            }
            var dictParts = parts.slice(0, info.index)
            var dict = Object.assign({}, getParts(dictParts, {}))
            dict[parts[info.index]] = rank
            return commit(dictParts, pruneRanks(dict))
        }

        console.warn("[SettingsManager] путь не описан в схеме:", parts.join("."))
        return false
    }

    function commit(parts, validated) {
        if (deepEqual(getParts(parts, undefined), validated))
            return false
        root.settings = assocIn(root.settings, parts, 0, validated)
        root.keyChanged(parts.join("."))
        scheduleSave()
        return true
    }

    function assocIn(node, parts, idx, value) {
        var copy = Object.assign({}, isObject(node) ? node : {})
        var key = parts[idx]
        copy[key] = (idx === parts.length - 1)
            ? value
            : assocIn(copy[key], parts, idx + 1, value)
        return copy
    }

    function scheduleSave() {
        saveTimer.restart()
    }

    // ============================================================
    //  ЗАГРУЗКА / СОХРАНЕНИЕ
    // ============================================================

    function loadFromDisk() {
        if (!root._constructed)
            return

        var raw = settingsFile.text()

        // Эхо собственной записи или повтор события с тем же содержимым:
        // парсить и валидировать нечего
        if (root.ready && raw === root._diskText)
            return
        root._diskText = raw

        if (raw.length > root.maxFileBytes) {
            handleBadFile(raw, "файл слишком большой")
            return
        }

        var parsed
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            handleBadFile(raw, e)
            return
        }

        if (!isObject(parsed)) {
            handleBadFile(raw, "корень не объект")
            return
        }

        var validated = validateNode(parsed, root.defaults, "")
        var fixed = !deepEqual(parsed, validated)

        root._noWrite = false

        if (!root.ready) {
            root.settings = validated
            root.ready = true
        } else if (!deepEqual(validated, root.settings)) {
            root.settings = validated
        }

        if (fixed)
            scheduleSave()
    }

    function handleBadFile(raw, reason) {
        if (root.ready) {
            console.warn("[SettingsManager] settings.json временно невалиден, игнорирую:", reason)
            return
        }
        if (raw.trim().length > 0) {
            console.warn("[SettingsManager] settings.json повреждён (", reason, "), копия в .bak")
            try { backupFile.setText(raw) } catch (e) {}
        }
        createDefaultAndSave()
    }

    function handleLoadFailed(error) {
        if (!root._constructed) {
            root._hasPendingError = true
            root._pendingError = error
            return
        }
        if (root.ready)
            return
        if (error === FileViewError.FileNotFound) {
            createDefaultAndSave()
        } else {
            console.warn("[SettingsManager] не удалось прочитать настройки, работаю без записи:", error)
            root._noWrite = true
            root.settings = deepCopy(root.defaults)
            root.ready = true
        }
    }

    function createDefaultAndSave() {
        root.settings = deepCopy(root.defaults)
        root.ready = true
        root._noWrite = false
        writeToDisk()
    }

    function writeToDisk() {
        saveTimer.stop()
        if (!root.ready || root._noWrite)
            return
        var text = JSON.stringify(root.settings, null, 2) + "\n"
        if (text === root._diskText)
            return
        root._diskText = text
        try {
            settingsFile.setText(text)
        } catch (e) {
            root._diskText = ""
            console.warn("[SettingsManager] не удалось записать настройки:", e)
        }
    }

    // ============================================================
    //  ВАЛИДАЦИЯ
    // ============================================================

    function validateNode(value, def, path) {
        if (value === undefined || value === null)
            return deepCopy(def)

        var t = typeOf(def)

        if (t === "object") {
            if (!isObject(value))
                return deepCopy(def)

            var keys = Object.keys(def)
            if (keys.length === 0)
                return hasOwn(root.freeDictPaths, path) ? sanitizeRanks(value) : ({})

            var out = {}
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i]
                out[k] = validateNode(hasOwn(value, k) ? value[k] : undefined,
                                      def[k],
                                      path ? path + "." + k : k)
            }
            return out
        }

        if (t === "array")
            return Array.isArray(value) ? deepCopy(value) : deepCopy(def)

        if (typeOf(value) !== t) {
            var coerced = coercePrimitive(value, def)
            if (coerced === undefined)
                return deepCopy(def)
            value = coerced
        }
        return applyConstraints(path, value, def)
    }

    function applyConstraints(path, value, def) {
        var t = typeof def

        if (t === "number") {
            if (typeof value !== "number" || !isFinite(value))
                return def
            if (hasOwn(root.numberBounds, path)) {
                var b = root.numberBounds[path]
                value = Math.round(value)
                if (value < b[0]) return b[0]
                if (value > b[1]) return b[1]
            }
            return value
        }

        if (t === "string") {
            if (typeof value !== "string" || value.length > root.maxStringLength)
                return def
            if (hasOwn(root.allowedStrings, path) && root.allowedStrings[path].indexOf(value) === -1)
                return def
            if (hasOwn(root.stringPatterns, path) && !root.stringPatterns[path].test(value))
                return def
            return value
        }

        return value
    }

    function coercePrimitive(value, def) {
        var t = typeof def
        if (t === "number") {
            if (typeof value === "string" && value.trim().length > 0) {
                var n = Number(value)
                return isFinite(n) ? n : undefined
            }
            return undefined
        }
        if (t === "boolean") {
            if (typeof value === "string") {
                var lower = value.toLowerCase()
                if (lower === "true") return true
                if (lower === "false") return false
            }
            return undefined
        }
        if (t === "string") {
            if (typeof value === "number" || typeof value === "boolean")
                return String(value)
        }
        return undefined
    }

    // ---------- usageRanks ----------

    function sanitizeRank(v) {
        if (typeof v !== "number" || !isFinite(v) || v < 0)
            return undefined
        return Math.min(Math.floor(v), 1000000000)
    }

    function sanitizeRanks(dict) {
        var out = {}
        var keys = Object.keys(dict)
        for (var i = 0; i < keys.length; i++) {
            if (!isSafeKey(keys[i]))
                continue
            var r = sanitizeRank(dict[keys[i]])
            if (r !== undefined)
                out[keys[i]] = r
        }
        return pruneRanks(out)
    }

    function pruneRanks(dict) {
        var keys = Object.keys(dict)
        if (keys.length <= root.maxUsageEntries)
            return dict
        keys.sort(function (a, b) { return dict[b] - dict[a] })
        var out = {}
        for (var i = 0; i < root.maxUsageEntries; i++)
            out[keys[i]] = dict[keys[i]]
        return out
    }

    // ---------- схема ----------

    function resolveSchema(parts) {
        var node = root.defaults
        for (var i = 0; i < parts.length; i++) {
            if (!isObject(node))
                return { kind: "none" }
            if (Object.keys(node).length === 0)
                return hasOwn(root.freeDictPaths, parts.slice(0, i).join("."))
                    ? { kind: "free", index: i }
                    : { kind: "none" }
            if (!hasOwn(node, parts[i]))
                return { kind: "none" }
            node = node[parts[i]]
        }
        return { kind: "schema", def: node }
    }

    // ============================================================
    //  УТИЛИТЫ
    // ============================================================

    function hasOwn(o, k) {
        return Object.prototype.hasOwnProperty.call(o, k)
    }

    function isObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v)
    }

    function isSafeKey(k) {
        return typeof k === "string"
            && k.length > 0
            && k.length <= root.maxKeyLength
            && k !== "__proto__"
            && k !== "constructor"
            && k !== "prototype"
    }

    function splitPath(path) {
        var parts = Array.isArray(path) ? path
                  : (typeof path === "string" && path.length > 0 ? path.split(".") : null)
        if (!parts || parts.length === 0)
            return null
        for (var i = 0; i < parts.length; i++)
            if (!isSafeKey(parts[i]))
                return null
        return parts
    }

    function typeOf(v) {
        if (v === null) return "null"
        if (Array.isArray(v)) return "array"
        return typeof v
    }

    function deepCopy(v) {
        return (v === undefined || v === null) ? v : JSON.parse(JSON.stringify(v))
    }

    function deepEqual(a, b) {
        if (a === b) return true
        var ta = typeOf(a)
        if (ta !== typeOf(b)) return false

        if (ta === "object") {
            var ka = Object.keys(a)
            if (ka.length !== Object.keys(b).length) return false
            for (var i = 0; i < ka.length; i++) {
                if (!hasOwn(b, ka[i]) || !deepEqual(a[ka[i]], b[ka[i]]))
                    return false
            }
            return true
        }
        if (ta === "array") {
            if (a.length !== b.length) return false
            for (var j = 0; j < a.length; j++)
                if (!deepEqual(a[j], b[j]))
                    return false
            return true
        }
        return false
    }
}