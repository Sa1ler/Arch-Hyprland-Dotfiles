import QtQuick
import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    //  ЗАВИСИМОСТИ
    // ============================================================

    // SettingsManager. Он единственный владелец settings.json:
    // этот менеджер больше не читает и не пишет файл напрямую.
    property var settingsManager: null

    // Синхронизировать выбранную тему с ski
    property bool syncSki: true

    // ============================================================
    //  КОНСТАНТЫ
    // ============================================================

    readonly property int maxThemeFileBytes: 65536
    readonly property int maxSkiFileBytes: 1048576
    readonly property int maxExtraColors: 64
    readonly property string fallbackTheme: "default"

    // Должен совпадать с SettingsManager.stringPatterns["theme.current"],
    // иначе тему нельзя будет сохранить в настройках
    readonly property var themeNamePattern: /^[A-Za-z0-9_-]{1,64}$/
    readonly property var colorKeyPattern: /^[A-Za-z][A-Za-z0-9]{0,31}$/
    // #RGB, #RRGGBB, #AARRGGBB (порядок QML) или transparent
    readonly property var colorPattern: /^(?:#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|transparent)$/

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string themesPath: Quickshell.shellDir + "/../themes"
    readonly property string skiSettingsPath: root.homeDir.length > 0
        ? root.homeDir + "/.config/ski/settings.json" : ""

    readonly property var defaultColors: ({
        "background": "#0E1217", "surface": "#1A1F26", "surfaceHover": "#252C36",
        "surfaceSelected": "#2C3A50", "accent": "#5B9BFF", "text": "#F0F4F8",
        "textSecondary": "#9AA9B9", "textDisabled": "#5A6675", "textSelected": "#FFFFFF",
        "border": "#2A323D", "separator": "#262E38"
    })

    readonly property var builtinTheme: ({
        "file": "default", "name": "Default", "colors": root.defaultColors
    })

    // ============================================================
    //  СОСТОЯНИЕ
    // ============================================================

    property string currentTheme: "default"
    property var theme: root.builtinTheme
    readonly property var colors: root.theme.colors     // шорткат: themeManager.colors.accent
    property var themes: []
    property bool themesLoaded: false

    signal themeChanging()

    property bool initialized: false     // первое применение при старте идёт без themeChanging
    property bool _folderGuard: false
    property bool _skiPrimed: false
    property bool _warnedEmpty: false
    property string _localWanted: "default"   // используется, только если settingsManager не задан

    // ---------- связь с SettingsManager ----------
    readonly property bool _hasSettings: root.settingsManager !== null && root.settingsManager !== undefined
    readonly property bool settingsReady: root._hasSettings ? root.settingsManager.isReady === true : true

    // Желаемая тема. Источник истины: settings.theme.current.
    // Пока настройки не загружены, пусто, и ничего не применяется.
    readonly property string wantedTheme: {
        if (!root._hasSettings)
            return root._localWanted
        return root.settingsManager.isReady ? String(root.settingsManager.currentTheme) : ""
    }

    // Qt.callLater склеивает несколько вызовов за один проход цикла событий в один
    onWantedThemeChanged: Qt.callLater(root.syncTheme)
    onSettingsReadyChanged: Qt.callLater(root.syncTheme)

    // ============================================================
    //  СПИСОК ТЕМ
    // ============================================================

    FolderListModel {
        id: themeFolder
        folder: "file://" + root.themesPath
        nameFilters: ["*.json"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                rescan.restart()
        }
    }

    // Один FileView на файл темы. Парсинг выполняется один раз при загрузке файла
    // и кэшируется в `parsed`. Пересбор списка использует готовые объекты.
    Instantiator {
        id: themeFiles
        model: themeFolder
        delegate: FileView {
            id: tf
            required property string fileName
            readonly property string stem: tf.fileName.slice(0, -5)
            property var parsed: null        // последняя ВАЛИДНАЯ версия темы
            property string rawCache: ""     // последний обработанный текст файла

            path: root.themesPath + "/" + tf.fileName
            blockLoading: true
            watchChanges: true
            printErrors: false

            onFileChanged: reload()
            onLoaded: {
                // Редакторы шлют несколько событий на одно сохранение.
                // Если текст не изменился, JSON.parse и сравнения не нужны.
                var raw = tf.text()
                if (raw === tf.rawCache)
                    return
                tf.rawCache = raw

                // Пока редактор пишет файл, он может быть временно невалиден:
                // держим последнюю хорошую версию, чтобы тема не мигала
                var p = root.parseTheme(tf.stem, raw)
                if (p && !root.sameTheme(p, tf.parsed)) {
                    tf.parsed = p
                    rescan.restart()
                }
            }
            // Исчезновение файла обрабатывает onObjectRemoved. Здесь ничего не сбрасываем,
            // иначе атомарная замена файла редактором вызвала бы мигание.
        }
        onObjectAdded: rescan.restart()
        onObjectRemoved: rescan.restart()
    }

    // Серия событий превращается в один пересбор
    Timer {
        id: rescan
        interval: 40
        onTriggered: root.collectThemes()
    }

    // Страховка на случай, если папка тем не стала Ready. Работает только пока
    // папка не готова: при нормальном старте таймер останавливается сам.
    Timer {
        interval: 1500
        running: !root._folderGuard && themeFolder.status !== FolderListModel.Ready
        onTriggered: {
            root._folderGuard = true
            rescan.restart()
        }
    }

    // ============================================================
    //  НАСТРОЙКИ SKI
    // ============================================================

    FileView {
        id: skiFile
        // Если синхронизация выключена, файл не читаем и не отслеживаем (экономия inotify и памяти)
        path: root.syncSki ? root.skiSettingsPath : ""
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // Один раз: покрывает случай, когда файл ski появился позже старта.
            // Дальше внешние правки ski не перетираем.
            if (!root._skiPrimed) {
                root._skiPrimed = true
                if (root.initialized)
                    root.syncSkiTheme()
            }
        }
    }

    // ============================================================
    //  ПУБЛИЧНЫЙ API
    // ============================================================

    // Переключить тему. Возвращает true, если тема теперь активна.
    function loadTheme(name) {
        var t = root.findTheme(String(name))
        if (!t)
            return false
        if (root._hasSettings)
            root.settingsManager.setCurrentTheme(t.file)   // сохранится и вызовет применение
        else
            root._localWanted = t.file
        root.syncTheme()
        return root.currentTheme === t.file
    }

    // Следующая/предыдущая тема по кругу: cycleTheme(1), cycleTheme(-1)
    function cycleTheme(delta) {
        var list = root.themes
        var n = list.length
        if (n === 0)
            return
        var idx = 0
        for (var i = 0; i < n; i++) {
            if (list[i].file === root.currentTheme) {
                idx = i
                break
            }
        }
        var step = delta === undefined ? 1 : delta
        root.loadTheme(list[((idx + step) % n + n) % n].file)
    }

    function findTheme(name) {
        var list = root.themes
        for (var i = 0; i < list.length; i++) {
            if (list[i].file === name)
                return list[i]
        }
        return null
    }

    // ============================================================
    //  ВНУТРЕННЯЯ ЛОГИКА
    // ============================================================

    function collectThemes() {
        var list = []
        for (var i = 0; i < themeFiles.count; i++) {
            var d = themeFiles.objectAt(i)
            if (d && d.parsed)
                list.push(d.parsed)
        }
        list.sort(function (a, b) { return a.file < b.file ? -1 : (a.file > b.file ? 1 : 0) })

        // Не пересоздаём список, если он не изменился: UI не перестраивает модели зря
        if (!root.sameList(list, root.themes))
            root.themes = list

        var ready = themeFolder.status === FolderListModel.Ready || root._folderGuard
        if (ready !== root.themesLoaded)
            root.themesLoaded = ready

        if (ready && list.length === 0 && !root._warnedEmpty) {
            root._warnedEmpty = true
            console.warn("[ThemeManager] тем не найдено в", root.themesPath, ", использую встроенную")
        }

        root.syncTheme()
    }

    function resolveTheme(name) {
        return root.findTheme(name)
            || root.findTheme(root.fallbackTheme)
            || (root.themes.length > 0 ? root.themes[0] : root.builtinTheme)
    }

    // Идемпотентная сверка: желаемая тема из настроек -> применённая.
    // Вызывается при изменении настроек, списка тем или содержимого файла темы.
    // Ничего не пишет в settings.json, поэтому цикла "применил -> записал -> перечитал" нет.
    // Если желаемой темы нет (файл удалён или временно сломан), показываем запасную,
    // но выбор пользователя в настройках не затираем: тема может вернуться.
    function syncTheme() {
        if (!root.themesLoaded || !root.settingsReady)
            return

        var target = root.resolveTheme(root.wantedTheme)
        var changed = target.file !== root.currentTheme

        if (changed && root.initialized)
            root.themeChanging()

        if (changed || !root.initialized || !root.sameTheme(target, root.theme)) {
            root.currentTheme = target.file
            root.theme = target        // также горячая перезагрузка цветов при правке файла темы
        }

        if (changed || !root.initialized)
            root.syncSkiTheme()

        root.initialized = true
    }

    // Меняет только ключ "theme" в ski. Если файла нет, он слишком большой
    // или не является JSON-объектом, ничего не пишет.
    function syncSkiTheme() {
        if (!root.syncSki || root.skiSettingsPath.length === 0 || !skiFile.loaded)
            return
        var raw = skiFile.text()
        if (raw.length === 0 || raw.length > root.maxSkiFileBytes)
            return

        var data
        try {
            data = JSON.parse(raw)
        } catch (e) {
            return
        }
        if (!root.isObject(data))
            return

        var value = "custom:" + root.currentTheme
        if (data.theme === value)
            return
        data.theme = value
        try {
            // Запись асинхронная: UI не ждёт диск
            skiFile.setText(JSON.stringify(data, null, 2) + "\n")
        } catch (e) {
            console.warn("[ThemeManager] не удалось записать настройки ski:", e)
        }
    }

    // ---------- парсинг и валидация темы ----------

    function parseTheme(stem, raw) {
        if (!root.themeNamePattern.test(stem)) {
            console.warn("[ThemeManager] недопустимое имя файла темы (разрешены A-Z a-z 0-9 _ -):", stem)
            return null
        }
        if (typeof raw !== "string" || raw.length === 0 || raw.length > root.maxThemeFileBytes)
            return null

        var data
        try {
            data = JSON.parse(raw)
        } catch (e) {
            console.warn("[ThemeManager] тема", stem, "содержит невалидный JSON:", e)
            return null
        }
        if (!root.isObject(data) || !root.isObject(data.colors))
            return null

        var name = typeof data.name === "string" ? data.name.trim().slice(0, 64) : ""
        return {
            "file": stem,
            "name": name.length > 0 ? name : stem,
            "colors": root.mergeColors(data.colors)
        }
    }

    // Базовые цвета + валидные цвета из темы. Невалидное значение не пропускаем:
    // вместо него остаётся дефолт, поэтому в QML не попадёт мусорная строка.
    function mergeColors(src) {
        // Свойства QML читаются один раз, а не на каждой итерации цикла
        var defaults = root.defaultColors
        var colorRe = root.colorPattern
        var keyRe = root.colorKeyPattern
        var maxExtra = root.maxExtraColors
        var hasOwn = Object.prototype.hasOwnProperty

        var out = Object.assign({}, defaults)
        var keys = Object.keys(src)
        var extra = 0
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            var v = src[k]
            if (typeof v !== "string")
                continue
            v = v.trim()
            if (!colorRe.test(v))
                continue
            if (!hasOwn.call(defaults, k)) {
                // Дополнительные цвета темы: безопасное имя и лимит количества
                if (!keyRe.test(k) || ++extra > maxExtra)
                    continue
            }
            out[k] = v
        }
        return out
    }

    // ---------- утилиты ----------

    function isObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v)
    }

    function sameTheme(a, b) {
        if (a === b)
            return true
        if (!a || !b || a.file !== b.file || a.name !== b.name)
            return false
        var ca = a.colors
        var cb = b.colors
        var ka = Object.keys(ca)
        if (ka.length !== Object.keys(cb).length)
            return false
        for (var i = 0; i < ka.length; i++) {
            if (ca[ka[i]] !== cb[ka[i]])
                return false
        }
        return true
    }

    function sameList(a, b) {
        if (a === b)
            return true
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++) {
            if (!root.sameTheme(a[i], b[i]))
                return false
        }
        return true
    }
}