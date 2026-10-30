-- ============================================================
-- RepertoireDB_Monitor.lua
-- Finestra floating: riepilogo banche dati e durate sorgente
--
-- Autore: Tommaso Feraboli — Film Editor
-- Versione: 1.2.5
-- Compatibile con DaVinci Resolve 19/20 (macOS e Windows)
--
-- Licenza MIT — vedi LICENSE.md
-- Copyright (c) 2024-2026 Tommaso Feraboli
-- Permesso concesso a chiunque di usare, copiare, modificare e
-- distribuire questo software, a condizione che il presente
-- avviso di copyright rimanga in tutti i file derivati.
--
-- Sostieni il progetto: https://paypal.me/acoffeefortom
-- ============================================================

local VERSION = "1.4.0"

local LogManager = require("LogManager")
LogManager:init()

local BugReportDialog = require("BugReportDialog")
-- Valori di dominio ed etichette tradotte: definiti una volta sola in
-- Settings, mai riscritti a mano qui.
local Settings = require("Settings")
-- Traduzione del testo dell'interfaccia. La chiave è il testo italiano
-- stesso: se la traduzione manca, o Strings.lua non è installato,
-- compare l'italiano invece di una sigla.
local T = Settings.t


local function getResolveVersion()
    local ok, result = pcall(function()
        local r = resolve
        if not r then return nil end
        if r.GetVersionString then
            local s = r:GetVersionString()
            if s and s ~= "" then return s end
        end
        if r.GetVersion then
            local v = r:GetVersion()
            if type(v) == "table" then
                local maj = v.major or v[1] or "?"
                local min = v.minor or v[2] or "?"
                return tostring(maj) .. "." .. tostring(min)
            elseif type(v) == "string" and v ~= "" then
                return v
            end
        end
        return nil
    end)
    if ok and result then return result end
    return "Unknown"
end

local function reportBug(scriptName, version)
    LogManager:info("Monitor.lua", "Segnalazione bug aperta - " .. scriptName .. " v" .. version)

    -- Mostra privacy notice e template
    BugReportDialog:show(scriptName, version)

    -- Tenta di aprire il client email
    local ok = pcall(function()
        BugReportDialog:sendEmail(scriptName, version)
    end)

    if ok then
        LogManager:info("Monitor.lua", "Bug report - client email aperto")
    else
        LogManager:warn("Monitor.lua", "Bug report - errore apertura client email")
    end

    -- Apri PayPal
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('start "" "https://paypal.me/acoffeefortom"')
    else
        os.execute('open "https://paypal.me/acoffeefortom"')
    end
end

local METADATA_FIELD = "Keywords"
local FONT_SIZE_MAIN = 18
local FONT_SIZE_SUB  = 13

-- Palette flag Resolve (nomi esatti del menu Timeline > Select Clips > By Flag Color)
local FLAG_COLORS = {
    "Blue", "Cyan", "Green", "Yellow", "Red", "Pink",
    "Purple", "Fuchsia", "Rose", "Lavender", "Sky", "Mint",
    "Lemon", "Sand", "Cocoa", "Cream"
}
local N_FLAGS = #FLAG_COLORS  -- 16

local validBankNames = {}   -- { [name] = mediaType }
local flaggedClips   = {}   -- clip a cui abbiamo aggiunto flag
local activeFlags    = {}   -- colori flag correnti { color1, ?color2 }
local bankFlagMap    = {}   -- { [bankName] = { color1, ?color2 } }

-- buildFlagMap(names) → table
-- Assegna 1 flag (hash deterministico) a ogni banca.
-- Se due banche collidono sullo stesso colore primario, la seconda riceve un secondo flag.
local function buildFlagMap(names)
    local result        = {}
    local primaryClaimed = {}
    table.sort(names)
    for _, name in ipairs(names) do
        local h = 0
        for i = 1, #name do h = (h * 31 + string.byte(name, i)) % N_FLAGS end
        if not primaryClaimed[h] then
            primaryClaimed[h] = true
            result[name] = { FLAG_COLORS[h + 1] }
        else
            local h2 = (h + math.floor(N_FLAGS / 2)) % N_FLAGS
            if h2 == h then h2 = (h2 + 1) % N_FLAGS end
            result[name] = { FLAG_COLORS[h + 1], FLAG_COLORS[h2 + 1] }
        end
    end
    return result
end

-- ============================================================
-- PERCORSO CONFIG
-- ============================================================
local function getConfigPath()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\repertoire_db.json"
    end
    local home = os.getenv("HOME") or "."
    local f = io.open(home .. "/Library/Application Support/Blackmagic Design", "r")
    if f then
        f:close()
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_db.json"
    end
    return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_db.json"
end

local function loadDB()
    local json = require("dkjson")
    local f = io.open(getConfigPath(), "r")
    if not f then return {} end
    local content = f:read("*all"); f:close()
    local data = json.decode(content)
    return data or {}
end

local function dbByName(db)
    local t = {}
    for _, e in ipairs(db) do t[e.name] = e end
    return t
end

-- ============================================================
-- FRAME HELPERS
-- ============================================================
local function framesToHMS(frames, fps)
    fps = tonumber(fps) or 25
    frames = math.abs(math.floor(frames + 0.5))
    local totalSec = math.floor(frames / fps)
    local ss = totalSec % 60
    local mm = math.floor(totalSec / 60) % 60
    local hh = math.floor(totalSec / 3600)
    return string.format("%02d:%02d:%02d", hh, mm, ss)
end

-- ============================================================
-- DURATA SORGENTE
-- ============================================================
local function getSourceFrames(clip)
    local inF  = clip:GetSourceStartFrame()
    local outF = clip:GetSourceEndFrame()
    if inF and outF and inF > outF then inF, outF = outF, inF end
    if inF and outF and inF == outF then
        local tlDur = clip:GetDuration()
        if tlDur and tlDur > 1 then outF = inF + 1 end
    end
    if not inF or not outF then return nil, nil end
    return inF, outF
end

-- ============================================================
-- HELPERS DEDUPLICAZIONE
-- ============================================================
local function uniqueFramesIn(inF, outF, covered)
    local overlap = 0
    for _, iv in ipairs(covered) do
        local lo = math.max(inF, iv[1])
        local hi = math.min(outF, iv[2])
        if hi > lo then overlap = overlap + (hi - lo) end
    end
    return math.max(0, (outF - inF) - overlap)
end

local function addInterval(covered, inF, outF)
    if inF >= outF then return covered end
    table.insert(covered, {inF, outF})
    table.sort(covered, function(a, b) return a[1] < b[1] end)
    local merged = {}
    local cur = {covered[1][1], covered[1][2]}
    for i = 2, #covered do
        if covered[i][1] <= cur[2] then
            cur[2] = math.max(cur[2], covered[i][2])
        else
            table.insert(merged, cur)
            cur = {covered[i][1], covered[i][2]}
        end
    end
    table.insert(merged, cur)
    return merged
end

-- ============================================================
-- SCANSIONE + AGGREGAZIONE
-- ============================================================
local function scan()
    local resolve  = app:GetResolve()
    local project  = resolve:GetProjectManager():GetCurrentProject()
    if not project then return nil, "Nessun progetto aperto" end

    local timeline = project:GetCurrentTimeline()
    if not timeline then return nil, "Nessuna timeline attiva" end

    local db = loadDB()
    if #db == 0 then return nil, "Nessuna banca dati configurata" end
    LogManager:info("Monitor.lua", "Video banks caricati - " .. #db .. " banche")
    local dbMap = dbByName(db)

    local fpsStr = timeline:GetSetting("timelineFrameRate")
    local fps    = tonumber(fpsStr) or 25
    if math.abs(fps - 29.97) < 0.1 then fps = 30000/1001 end
    if math.abs(fps - 59.94) < 0.1 then fps = 60000/1001 end

    local videoGroups  = {}
    local fotoGroups   = {}
    local videoSegsMap = {}   -- { [dbName] = count }
    local audioSegsMap = {}   -- { [dbName] = count }

    local trackCount = timeline:GetTrackCount("video")
    for trackIdx = 1, trackCount do
        local clips = timeline:GetItemListInTrack("video", trackIdx)
        if clips then
            for _, clip in ipairs(clips) do
                pcall(function()
                    local mi = clip:GetMediaPoolItem()
                    if not mi then return end

                    local kwRaw = mi:GetMetadata(METADATA_FIELD)
                    if not kwRaw or kwRaw == "" then return end

                    local dbName, entry = nil, nil
                    for tok in (kwRaw .. ";"):gmatch("([^;,\n]*)[;,\n]") do
                        tok = tok:match("^%s*(.-)%s*$")
                        if tok ~= "" and dbMap[tok] then
                            dbName = tok
                            entry  = dbMap[tok]
                            break
                        end
                    end
                    if not dbName then return end

                    videoSegsMap[dbName] = (videoSegsMap[dbName] or 0) + 1

                    local mt = entry.mediaType or Settings.MEDIA.VIDEO

                    if mt == Settings.MEDIA.VIDEO then
                        local key = mi:GetUniqueId() .. "|" .. dbName
                        if not videoGroups[key] then
                            videoGroups[key] = { dbName=dbName, covered={}, uniqueFr=0 }
                        end
                        local inF, outF = getSourceFrames(clip)
                        if not inF then return end
                        local uniq = uniqueFramesIn(inF, outF, videoGroups[key].covered)
                        videoGroups[key].covered  = addInterval(videoGroups[key].covered, inF, outF)
                        videoGroups[key].uniqueFr = videoGroups[key].uniqueFr + uniq
                    else
                        if not fotoGroups[dbName] then
                            fotoGroups[dbName] = { ids={}, rate=entry.rate, mediaType=mt }
                        end
                        fotoGroups[dbName].ids[mi:GetUniqueId()] = true
                    end
                end)
            end
        end
    end

    -- Scansione tracce audio
    local audioTrackCount = timeline:GetTrackCount("audio")
    for trackIdx = 1, audioTrackCount do
        local clips = timeline:GetItemListInTrack("audio", trackIdx)
        if clips then
            for _, clip in ipairs(clips) do
                pcall(function()
                    local mi = clip:GetMediaPoolItem()
                    if not mi then return end
                    local kwRaw = mi:GetMetadata(METADATA_FIELD)
                    if not kwRaw or kwRaw == "" then return end
                    for tok in (kwRaw .. ";"):gmatch("([^;,\n]*)[;,\n]") do
                        tok = tok:match("^%s*(.-)%s*$")
                        if tok ~= "" and dbMap[tok] then
                            audioSegsMap[tok] = (audioSegsMap[tok] or 0) + 1
                            return
                        end
                    end
                end)
            end
        end
    end

    local videoByDB = {}
    local totFr     = 0
    for _, g in pairs(videoGroups) do
        if not videoByDB[g.dbName] then
            videoByDB[g.dbName] = { frames=0, fps=fps }
        end
        videoByDB[g.dbName].frames = videoByDB[g.dbName].frames + g.uniqueFr
        totFr = totFr + g.uniqueFr
    end

    local fotoByDB = {}
    for dbName, g in pairs(fotoGroups) do
        local count = 0
        for _ in pairs(g.ids) do count = count + 1 end
        fotoByDB[dbName] = {
            clipCount = count,
            cost      = count * (g.rate or 0),
            mediaType = g.mediaType,
        }
    end

    return videoByDB, fotoByDB, { frames=totFr, fps=fps }, timeline:GetName(), videoSegsMap, audioSegsMap
end

-- ============================================================
-- UI
-- ============================================================
local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local COLOR_A = { R=1,    G=1,    B=1,    A=1 }
local COLOR_B = { R=0.65, G=0.65, B=0.65, A=1 }

local win = disp:AddWindow({
    ID = "RDB_Monitor",
    WindowTitle = string.format(T("RepertoireDB v%s — Monitor"), VERSION),
    Geometry = { 120, 120, 640, 560 },
    ui:VGroup{
        ui:HGroup{
            ui:Label{ Text  = T("RepertoireDB v") .. VERSION,
                Font = ui:Font{ PixelSize = 20 },
                StyleSheet = "color: #DCDCDC;" },
            ui:HGap{},
            ui:VGroup{
                ui:Label{ Text  = T("© Tommaso Feraboli Film Editor"),
                    Alignment = { AlignRight = true },
                    Font = ui:Font{ PixelSize = 13 },
                    StyleSheet = "color: #D2D2D2;" },
                ui:Label{ Text  = T("MIT License"),
                    Alignment = { AlignRight = true },
                    Font = ui:Font{ PixelSize = 10, Italic = true },
                    StyleSheet = "color: #828282; margin-top: 0px;" },
            },
        },
        ui:Tree{
            ID   = "BancaTree",
            RootIsDecorated = false,
            AlternatingRowColors = true,
            SelectionMode = "SingleSelection",
            ToolTip  = T("Clicca su una banca per selezionarne i segmenti in timeline"),
            MinimumSize = { 620, 380 },
        },
        ui:HGroup{
            ui:CheckBox{ ID="ChkFoto", Text = T("Mostra Fotografie e Giornali"),
                Checked=false,
                Font = ui:Font{ PixelSize=FONT_SIZE_SUB },
                MinimumSize={280,22} },
            ui:HGap{},
        },
        ui:HGroup{
            ui:Label{ ID="LblInfo", Text="",
                Font = ui:Font{ PixelSize=FONT_SIZE_SUB, Italic=true },
                MinimumSize={300,22} },
            ui:HGap{},
            ui:Button{ ID="BtnRefresh", Text = T("↺  Aggiorna"), MinimumSize={120,30} },
        },
        ui:HGroup{
            ui:HGap{},
            ui:VGroup{ Spacing=1,
                ui:Button{ ID="BtnReadme", Text="📖", MinimumSize={80,52},
                    ToolTip = T("Apre il file README"),
                    StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #8B7B1A,stop:1 #5A4E0A);color:#FFE97A;border-radius:5px;border:1px solid #5A4E0A;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #A08A20,stop:1 #8B7B1A);}]] },
                ui:Label{ Text = T("Guida"), Alignment={AlignHCenter=true},
                    StyleSheet="color:#8B7B1A; font-size:10px; margin:0;" },
            },
            ui:VGroup{ Spacing=1,
                ui:Button{ ID="BtnCoffee", Text="☕", MinimumSize={80,52},
                    ToolTip = T("Supporta il progetto su PayPal"),
                    StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #2196C0,stop:1 #1565A0);color:#FFFFFF;border-radius:5px;border:1px solid #1565A0;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #2AA8D8,stop:1 #2196C0);}]] },
                ui:Label{ Text = T("Offrimi un caffè"), Alignment={AlignHCenter=true},
                    StyleSheet="color:#2196C0; font-size:10px; margin:0;" },
            },
            ui:VGroup{ Spacing=1,
                ui:Button{ ID="BtnBug", Text="🐛", MinimumSize={80,52},
                    ToolTip = T("Invia una segnalazione bug a tomfilmeditor.tools@gmail.com"),
                    StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #B03020,stop:1 #7A1E10);color:#FFFFFF;border-radius:5px;border:1px solid #7A1E10;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #C84030,stop:1 #B03020);}]] },
                ui:Label{ Text = T("Riporta bug"), Alignment={AlignHCenter=true},
                    StyleSheet="color:#B03020; font-size:10px; margin:0;" },
            },
            ui:HGap{},
        },
    },
})

local hdr = win:Find("BancaTree"):NewItem()
hdr.Text[0] = T("Banca dati")
hdr.Text[1] = T("Durata / Clip")
hdr.Text[2] = T("Seg. Video")
hdr.Text[3] = T("Seg. Audio")
win:Find("BancaTree"):SetHeaderItem(hdr)
win:Find("BancaTree").ColumnCount = 4
win:Find("BancaTree"):SetColumnWidth(0, 220)
win:Find("BancaTree"):SetColumnWidth(1, 120)
win:Find("BancaTree"):SetColumnWidth(2, 110)
win:Find("BancaTree"):SetColumnWidth(3, 110)

-- ============================================================
-- REFRESH
-- ============================================================
local function refresh()
    LogManager:debug("Monitor.lua", "Aggiornamento timeline - scan in corso")
    local tree      = win:Find("BancaTree")
    local showFoto  = win:Find("ChkFoto").Checked
    tree:Clear()
    validBankNames = {}

    local videoByDB, fotoByDB, totals, tlName, videoSegs, audioSegs = scan()

    if not videoByDB then
        local errMsg = fotoByDB or "Errore sconosciuto"
        LogManager:error("Monitor.lua", "Errore calcolo durata banca: " .. errMsg)
        local err = tree:NewItem()
        err.Text[0] = "⚠  " .. errMsg
        err.Font[0] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Italic=true }
        tree:AddTopLevelItem(err)
        win:Find("LblInfo").Text = ""
        return
    end

    local fps    = totals.fps
    local rowIdx = 0

    -- ── VIDEO ──────────────────────────────────────────────────
    local videoNames = {}
    for k in pairs(videoByDB) do table.insert(videoNames, k) end
    table.sort(videoNames)

    local totVSegs, totASegs = 0, 0
    for _, name in ipairs(videoNames) do
        rowIdx = rowIdx + 1
        local d     = videoByDB[name]
        local dur   = framesToHMS(d.frames, d.fps)
        local color = (rowIdx % 2 == 1) and COLOR_A or COLOR_B
        local vs    = videoSegs[name] or 0
        local as_   = audioSegs[name] or 0
        totVSegs = totVSegs + vs
        totASegs = totASegs + as_
        local it    = tree:NewItem()
        it.Text[0]      = name
        it.Text[1]      = dur
        it.Text[2]      = tostring(vs)
        it.Text[3]      = tostring(as_)
        it.Font[0]      = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
        it.Font[1]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
        it.Font[2]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
        it.Font[3]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
        it.TextColor[0] = color
        it.TextColor[1] = color
        it.TextColor[2] = color
        it.TextColor[3] = color
        tree:AddTopLevelItem(it)
        validBankNames[name] = Settings.MEDIA.VIDEO
    end

    if #videoNames > 1 then
        local sep = tree:NewItem()
        sep.Text[0] = string.rep("─", 26)
        tree:AddTopLevelItem(sep)
        local tot = tree:NewItem()
        tot.Text[0] = T("TOTALE VIDEO")
        tot.Text[1] = framesToHMS(totals.frames, fps)
        tot.Text[2] = tostring(totVSegs)
        tot.Text[3] = tostring(totASegs)
        tot.Font[0] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
        tot.Font[1] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
        tot.Font[2] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
        tot.Font[3] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
        tree:AddTopLevelItem(tot)
    end

    -- ── FOTOGRAFIE e GIORNALI (opzionale) ──────────────────────
    if showFoto then
        local cats  = { Settings.MEDIA.PHOTO, Settings.MEDIA.PRESS }
        local byCat = {}
        for _, c in ipairs(cats) do byCat[c] = {} end
        for name, d in pairs(fotoByDB) do
            local c = d.mediaType
            if byCat[c] then table.insert(byCat[c], name) end
        end

        for _, cat in ipairs(cats) do
            local names = byCat[cat]
            if #names > 0 then
                table.sort(names)

                local sep = tree:NewItem()
                sep.Text[0] = string.rep("─", 26)
                tree:AddTopLevelItem(sep)
                local catHdr = tree:NewItem()
                catHdr.Text[0] = string.upper(Settings.mediaLabel(cat))
                catHdr.Font[0] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                tree:AddTopLevelItem(catHdr)

                local catTotClip  = 0
                local catTotVSegs = 0
                local catTotASegs = 0
                local fotoIdx     = 0

                for _, name in ipairs(names) do
                    fotoIdx  = fotoIdx + 1
                    local d  = fotoByDB[name]
                    local color = (fotoIdx % 2 == 1) and COLOR_A or COLOR_B
                    local vs = videoSegs[name] or 0
                    local as_ = audioSegs[name] or 0
                    catTotClip  = catTotClip  + d.clipCount
                    catTotVSegs = catTotVSegs + vs
                    catTotASegs = catTotASegs + as_

                    local it = tree:NewItem()
                    it.Text[0]      = name
                    it.Text[1]      = d.clipCount .. " clip"
                    it.Text[2]      = tostring(vs)
                    it.Text[3]      = tostring(as_)
                    it.Font[0]      = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                    it.Font[1]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
                    it.Font[2]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
                    it.Font[3]      = ui:Font{ PixelSize=FONT_SIZE_MAIN }
                    it.TextColor[0] = color
                    it.TextColor[1] = color
                    it.TextColor[2] = color
                    it.TextColor[3] = color
                    tree:AddTopLevelItem(it)
                    validBankNames[name] = d.mediaType
                end

                if #names > 1 then
                    local sub = tree:NewItem()
                    sub.Text[0] = T("Totale ") .. cat
                    sub.Text[1] = catTotClip .. " clip"
                    sub.Text[2] = tostring(catTotVSegs)
                    sub.Text[3] = tostring(catTotASegs)
                    sub.Font[0] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                    sub.Font[1] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                    sub.Font[2] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                    sub.Font[3] = ui:Font{ PixelSize=FONT_SIZE_MAIN, Bold=true }
                    tree:AddTopLevelItem(sub)
                end
            end
        end
    end

    -- Ricostruisce la mappa flag per tutte le banche visibili
    local allNames = {}
    for name in pairs(validBankNames) do table.insert(allNames, name) end
    bankFlagMap = buildFlagMap(allNames)

    win:Find("LblInfo").Text = string.format(T("%s  —  aggiornato %s"), tlName or "?", os.date("%H:%M:%S"))
end

-- ============================================================
-- EVIDENZIAZIONE TIMELINE
-- ============================================================

-- clearHighlight() → void
-- Rimuove tutti i flag aggiunti dalla sessione corrente.
local function clearHighlight()
    for _, col in ipairs(activeFlags) do
        for _, c in ipairs(flaggedClips) do
            pcall(function() c:ClearFlags(col) end)
        end
    end
    flaggedClips = {}
    activeFlags  = {}
end

-- selectByFlagColorMenu(color) → void
-- Naviga il menu Timeline > Select Clips > By Flag Color > [color] via AppleScript.
local function selectByFlagColorMenu(color)
    local as =
        'tell application "DaVinci Resolve" to activate\n' ..
        'delay 0.2\n' ..
        'tell application "System Events"\n' ..
        '    tell process "DaVinci Resolve"\n' ..
        '        click menu bar item "Timeline" of menu bar 1\n' ..
        '        delay 0.15\n' ..
        '        tell menu item "Select Clips" of menu "Timeline" of menu bar item "Timeline" of menu bar 1\n' ..
        '            perform action "AXPress"\n' ..
        '        end tell\n' ..
        '        delay 0.15\n' ..
        '        tell menu item "By Flag Color" of menu 1 of menu item "Select Clips" of menu "Timeline" of menu bar item "Timeline" of menu bar 1\n' ..
        '            perform action "AXPress"\n' ..
        '        end tell\n' ..
        '        delay 0.15\n' ..
        '        click menu item "' .. color .. '" of menu 1 of menu item "By Flag Color" of menu 1 of menu item "Select Clips" of menu "Timeline" of menu bar item "Timeline" of menu bar 1\n' ..
        '    end tell\n' ..
        'end tell\n'
    local h = io.popen("osascript << 'ASEOF'\n" .. as .. "ASEOF")
    if h then h:read("*a"); h:close() end
end

-- selectBankInTimeline(bankName) → void
-- Aggiunge flag ai clip della banca, naviga il playhead al primo clip,
-- poi seleziona i clip tramite il menu Timeline > Select Clips > By Flag Color.
local function selectBankInTimeline(bankName)
    local resolveApp = app:GetResolve()
    local project    = resolveApp:GetProjectManager():GetCurrentProject()
    if not project then return end
    local timeline   = project:GetCurrentTimeline()
    if not timeline then return end

    local fpsStr = timeline:GetSetting("timelineFrameRate")
    local fps    = tonumber(fpsStr) or 25
    if math.abs(fps - 29.97) < 0.1 then fps = 30000/1001 end
    if math.abs(fps - 59.94) < 0.1 then fps = 60000/1001 end
    local fpsi = math.floor(fps + 0.5)

    clearHighlight()

    local flags      = bankFlagMap[bankName] or { FLAG_COLORS[1] }
    activeFlags      = flags

    local matchingClips = {}
    local firstFrame    = nil
    local trackCount    = timeline:GetTrackCount("video")

    for trackIdx = 1, trackCount do
        local clips = timeline:GetItemListInTrack("video", trackIdx)
        if clips then
            for _, clip in ipairs(clips) do
                pcall(function()
                    local mi = clip:GetMediaPoolItem()
                    if not mi then return end
                    local kwRaw = mi:GetMetadata(METADATA_FIELD)
                    if not kwRaw or kwRaw == "" then return end
                    for tok in (kwRaw .. ";"):gmatch("([^;,\n]*)[;,\n]") do
                        tok = tok:match("^%s*(.-)%s*$")
                        if tok == bankName then
                            table.insert(matchingClips, clip)
                            local s = clip:GetStart()
                            if s and (firstFrame == nil or s < firstFrame) then
                                firstFrame = s
                            end
                            return
                        end
                    end
                end)
            end
        end
    end

    local count = #matchingClips
    if count == 0 then
        activeFlags = {}
        win:Find("LblInfo").Text = bankName .. ": nessun segmento"
        return
    end

    -- Applica flag a ogni clip della banca
    for _, c in ipairs(matchingClips) do
        pcall(function()
            for _, col in ipairs(flags) do
                c:AddFlag(col)
            end
            table.insert(flaggedClips, c)
        end)
    end

    -- Naviga il playhead al primo clip della banca
    if firstFrame then
        pcall(function()
            local f  = math.floor(firstFrame)
            local ff = f % fpsi
            local ts = math.floor(f / fpsi)
            local tc = string.format("%02d:%02d:%02d:%02d",
                math.floor(ts / 3600),
                math.floor(ts / 60) % 60,
                ts % 60,
                ff)
            timeline:SetCurrentTimecode(tc)
        end)
    end

    -- Seleziona i clip via menu (usa il flag primario)
    selectByFlagColorMenu(flags[1])

    local flagLabel = table.concat(flags, "+")
    win:Find("LblInfo").Text = string.format(
        count == 1 and T("▶ %s [%s] — %d segmento")
                   or  T("▶ %s [%s] — %d segmenti"),
        bankName, flagLabel, count)
end

-- ============================================================
-- HANDLERS
-- ============================================================
win.On.BancaTree.ItemClicked = function(ev)
    local item = ev.item or ev.Item
    if not item then return end
    local name = item.Text[0]
    if name and validBankNames[name] then
        selectBankInTimeline(name)
    end
end

win.On.BtnRefresh.Clicked        = function() refresh() end
win.On.ChkFoto.Clicked           = function() refresh() end
win.On.BtnBug.Clicked   = function() reportBug("RepertoireDB_Monitor.lua", VERSION) end
win.On.BtnReadme.Clicked = function()
    local sep  = package.config:sub(1,1)
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
    local path
    if sep == "\\" then
        path = (os.getenv("APPDATA") or "") .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\RepertoireDB_README.txt"
        os.execute('start "" "' .. path .. '"')
    else
        path = home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/RepertoireDB_README.txt"
        os.execute('open "' .. path .. '"')
    end
end
win.On.BtnCoffee.Clicked = function()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('start "" "https://paypal.me/acoffeefortom"')
    else
        os.execute('open "https://paypal.me/acoffeefortom"')
    end
end
win.On.RDB_Monitor.Close = function()
    LogManager:info("Monitor.lua", "Monitor chiuso")
    clearHighlight()
    disp:ExitLoop()
end

LogManager:info("Monitor.lua", "Monitor avviato per timeline")
refresh()

win:Show()
disp:RunLoop()
clearHighlight()
win:Hide()
