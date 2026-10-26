-- ============================================================
-- RepertoireDB_Installer.lua
-- Verifica e installa i prerequisiti per l'esportazione XLSX
-- (Python 3 e openpyxl)
--
-- Autore: Tommaso Feraboli — Film Editor
-- Versione: 1.2.5
-- Compatibile con DaVinci Resolve 19/20 (macOS e Windows)
--
-- Licenza MIT — vedi LICENSE.md
-- Copyright (c) 2024-2026 Tommaso Feraboli
--
-- Sostieni il progetto: https://paypal.me/acoffeefortom
-- ============================================================

local VERSION = "1.2.5"

local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local IS_WIN = (package.config:sub(1,1) == "\\")

-- ── PATH macOS visibile da Resolve (app GUI, no .zshrc) ─────────────────────
-- DaVinci Resolve lancia io.popen() con PATH di sistema, non quello della shell
-- interattiva dell'utente. Su macOS il PATH GUI è:
--   /usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
-- Su Windows si usa il comando "python" senza path assoluto.
local RESOLVE_PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

-- Candidati Python da verificare (in ordine di priorità per Resolve)
local CANDIDATES
if IS_WIN then
    CANDIDATES = {
        { path = "python",   label = "python  (PATH di sistema)" },
        { path = "python3",  label = "python3 (PATH di sistema)" },
    }
else
    CANDIDATES = {
        { path = "/usr/bin/python3",        label = "/usr/bin/python3        (usato da Resolve)" },
        { path = "/usr/local/bin/python3",  label = "/usr/local/bin/python3" },
        { path = "/opt/homebrew/bin/python3",label = "/opt/homebrew/bin/python3" },
    }
end

-- ── Funzioni di diagnostica ──────────────────────────────────────────────────

local function run(cmd)
    local h = io.popen(cmd .. " 2>&1")
    if not h then return "" end
    local out = h:read("*a"); h:close()
    return out or ""
end

-- Ritorna il path della directory config di RepertoireDB (usa uname -s, non io.open su dir)
local function getRepertoireDBDir()
    if IS_WIN then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB"
    end
    local home = os.getenv("HOME") or "."
    local h = io.popen("uname -s 2>/dev/null")
    local osname = h and h:read("*a") or ""; if h then h:close() end
    if osname:match("Darwin") then
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB"
    else
        return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB"
    end
end

-- Verifica e crea la directory se non esiste; testa la scrittura del JSON
local function checkAndFixConfigDir()
    local dir  = getRepertoireDBDir()
    local json = dir .. (IS_WIN and "\\repertoire_db.json" or "/repertoire_db.json")
    -- Crea la directory se mancante
    if IS_WIN then
        os.execute('mkdir "' .. dir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
    -- Crea il JSON vuoto se non esiste
    local f = io.open(json, "r")
    if f then f:close()
    else
        local fw = io.open(json, "w")
        if fw then fw:write("{}"); fw:close() end
    end
    -- Test scrittura
    local tw = io.open(json .. ".writetest", "w")
    if tw then tw:close(); os.remove(json .. ".writetest"); return true, dir end
    return false, dir
end

local function checkPython(pyPath)
    local out = run(string.format('"%s" --version', pyPath))
    return out:match("Python%s+(%d[%d%.]+)")
end

local function checkOpenpyxl(pyPath)
    local out = run(string.format('"%s" -c "import openpyxl; print(openpyxl.__version__)"', pyPath))
    local ver = out:match("^%s*(%d[%d%.]+)%s*$")
    return ver
end

-- Rileva quale python3 Resolve troverebbe nel suo PATH (solo macOS)
local function resolveDetectedPython()
    if IS_WIN then return nil end
    local out = run(string.format('env -i PATH="%s" which python3 2>/dev/null', RESOLVE_PATH))
    local p = out:match("^%s*(.-)%s*$")
    return (p ~= "" and p) or nil
end

local function installOpenpyxl(pyPath)
    local cmd = string.format('"%s" -m pip install --user openpyxl', pyPath)
    local out = run(cmd)
    local ok  = (out:lower():match("successfully installed") or
                 out:lower():match("already satisfied")) ~= nil
    return ok, out
end

local function openURL(url)
    if IS_WIN then
        os.execute(string.format('start "" "%s"', url))
    else
        os.execute(string.format('open "%s"', url))
    end
end

-- ── Costruisce la tabella di stato ───────────────────────────────────────────

local function buildStatus()
    local resolveTarget = resolveDetectedPython()
    local results = {}
    for _, cand in ipairs(CANDIDATES) do
        local pyVer   = checkPython(cand.path)
        local oxlVer  = pyVer and checkOpenpyxl(cand.path) or nil
        local isTarget = (cand.path == resolveTarget)
        table.insert(results, {
            path      = cand.path,
            label     = cand.label,
            pyVer     = pyVer,
            oxlVer    = oxlVer,
            isTarget  = isTarget,
        })
    end
    return results, resolveTarget
end

-- ── UI ───────────────────────────────────────────────────────────────────────

local function buildRows(results, resolveTarget)
    local rows = {}
    for _, r in ipairs(results) do
        local pyIcon  = r.pyVer   and "✓" or "✗"
        local oxlIcon = r.oxlVer  and "✓" or (r.pyVer and "✗" or "—")
        local marker  = r.isTarget and " ◀ usato da Resolve" or ""
        local row = ui:HGroup{
            ui:Label{
                Text = r.label .. marker,
                MinimumSize = { 320, 20 },
                StyleSheet  = r.isTarget
                    and "color: #FFFFFF; font-weight: bold;"
                    or  "color: #CCCCCC;",
            },
            ui:Label{
                Text = pyIcon .. " Python " .. (r.pyVer or "non trovato"),
                MinimumSize = { 165, 20 },
                StyleSheet  = r.pyVer
                    and "color: #7FD67F; font-weight: bold;"
                    or  "color: #E07070;",
            },
            ui:Label{
                Text = oxlIcon .. " openpyxl " .. (r.oxlVer or (r.pyVer and "non installato" or "")),
                MinimumSize = { 210, 20 },
                StyleSheet  = r.oxlVer
                    and "color: #7FD67F; font-weight: bold;"
                    or  (r.pyVer and "color: #E07070;" or "color: #888888;"),
            },
        }
        table.insert(rows, row)
    end
    return rows
end

local function openInstaller()
    -- Verifica directory config e scrittura JSON (fix bug Sonoma/Resolve 20-21)
    local configOK, configDir = checkAndFixConfigDir()
    local results, resolveTarget = buildStatus()

    -- Determina stato globale per i pulsanti
    local targetResult = nil
    local anyPython    = false
    for _, r in ipairs(results) do
        if r.pyVer then anyPython = true end
        if r.isTarget then targetResult = r end
    end

    -- Se non rilevato automaticamente, usa il primo Python disponibile
    if not targetResult then
        for _, r in ipairs(results) do
            if r.pyVer then targetResult = r; break end
        end
    end

    local needInstallOxl = targetResult and targetResult.pyVer and not targetResult.oxlVer
    local needPython     = not anyPython

    -- Costruisce righe dinamiche
    local statusRows = buildRows(results, resolveTarget)

    -- Crea la finestra
    local rowElements = {}
    for _, row in ipairs(statusRows) do
        table.insert(rowElements, row)
    end

    local win = disp:AddWindow({
        ID = "InstallerWin",
        WindowTitle = "RepertoireDB v" .. VERSION .. " — Installer prerequisiti XLSX",
        Geometry = { 120, 120, 760, 320 },
        ui:VGroup{
            -- Titolo
            ui:HGroup{
                ui:Label{
                    Text = "RepertoireDB v" .. VERSION .. " — Prerequisiti XLSX",
                    Font = ui:Font{ PixelSize = 16, Bold = true },
                    StyleSheet = "color: #DCDCDC;",
                },
                ui:HGap{},
                ui:Button{ ID="BtnCoffee", Text="☕", MinimumSize={34,34}, MaximumSize={34,34},
                    ToolTip="Sostieni il progetto su PayPal",
                    StyleSheet="font-size:18px;background-color:#555;border:1px solid #888;border-radius:4px;" },
            },
            ui:Label{
                Text = "Richiesti per esportare in formato Excel (.xlsx) da RepertoireDB Calculator.",
                StyleSheet = "color: #AAAAAA; margin-bottom: 2px;",
            },

            -- Stato directory config (fix Sonoma/Resolve 20-21)
            ui:HGroup{
                ui:Label{
                    Text = "Directory config JSON:",
                    MinimumSize = { 180, 20 },
                    StyleSheet  = "color: #9090C0; font-weight: bold;",
                },
                ui:Label{
                    Text = configOK and ("✓  " .. configDir) or ("⚠  Scrittura fallita — " .. configDir),
                    MinimumSize = { 520, 20 },
                    StyleSheet  = configOK
                        and "color: #7FD67F;"
                        or  "color: #E07070; font-weight: bold;",
                },
            },
            ui:HGap{ MinimumSize={0,4} },

            -- Intestazione tabella
            ui:HGroup{
                ui:Label{ Text="Percorso Python",   MinimumSize={320,18}, Font=ui:Font{Bold=true}, StyleSheet="color:#9090C0;" },
                ui:Label{ Text="Python 3",          MinimumSize={165,18}, Font=ui:Font{Bold=true}, StyleSheet="color:#9090C0;" },
                ui:Label{ Text="openpyxl",          MinimumSize={210,18}, Font=ui:Font{Bold=true}, StyleSheet="color:#9090C0;" },
            },

            -- Righe stato (inserite dinamicamente sotto)
            table.unpack(rowElements),

            ui:HGap{ MinimumSize={0,8} },

            -- Messaggio stato
            ui:Label{
                ID = "LblMsg",
                Text = "",
                WordWrap = true,
                StyleSheet = "color: #E0C070; font-style: italic;",
            },

            -- Pulsanti azione
            ui:HGroup{
                ui:Button{
                    ID      = "BtnInstall",
                    Text    = "⬇  Installa openpyxl",
                    MinimumSize = { 200, 34 },
                    Enabled = needInstallOxl,
                    ToolTip = targetResult and ("Installa openpyxl per " .. targetResult.path) or "",
                    StyleSheet = needInstallOxl
                        and "background-color:#2E6FA3;color:#FFFFFF;font-weight:bold;"
                        or  "",
                },
                ui:Button{
                    ID      = "BtnPython",
                    Text    = "🌐  Scarica Python 3",
                    MinimumSize = { 180, 34 },
                    Enabled = needPython,
                    ToolTip = "Apre python.org nel browser",
                },
                ui:Button{
                    ID      = "BtnRefresh",
                    Text    = "↺  Ricontrolla",
                    MinimumSize = { 140, 34 },
                },
                ui:HGap{},
                ui:Button{
                    ID      = "BtnClose",
                    Text    = "Chiudi",
                    MinimumSize = { 100, 34 },
                },
            },
        },
    })

    -- ── Handler pulsanti ────────────────────────────────────────────────────

    win.On.BtnInstall.Clicked = function()
        if not targetResult or not targetResult.pyVer then return end
        win:Find("LblMsg").Text = "Installazione in corso…"
        local ok, out = installOpenpyxl(targetResult.path)
        if ok then
            win:Find("LblMsg").Text = "✓ openpyxl installato correttamente. Riavvia Resolve se necessario."
        else
            local errLine = out:match("([^\n]+)$") or out:sub(1, 120)
            win:Find("LblMsg").Text = "⚠ Errore: " .. errLine
        end
        win:Find("BtnInstall").Enabled = false
    end

    win.On.BtnPython.Clicked = function()
        openURL("https://www.python.org/downloads/")
        win:Find("LblMsg").Text = "Browser aperto su python.org — installa Python 3, poi riavvia questo installer."
    end

    win.On.BtnRefresh.Clicked = function()
        win:Find("LblMsg").Text = "Verifica in corso…"
        disp:ExitLoop()
        openInstaller()
    end

    win.On.BtnCoffee.Clicked = function()
        openURL("https://paypal.me/acoffeefortom")
    end

    win.On.BtnClose.Clicked    = function() disp:ExitLoop() end
    win.On.InstallerWin.Close  = function() disp:ExitLoop() end

    win:Show()
    disp:RunLoop()
    win:Hide()
end

-- Avvia
openInstaller()
