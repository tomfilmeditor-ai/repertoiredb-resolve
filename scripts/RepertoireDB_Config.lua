-- ============================================================
-- RepertoireDB_Config.lua
-- Interfaccia di gestione banche dati archivi repertorio
--
-- Autore: Tommaso Feraboli — Film Editor
-- Versione: 1.2.2
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

local json = require("dkjson")

local VERSION = "1.2.14"

local LogManager = require("LogManager")
LogManager:init()

local BugReportDialog = require("BugReportDialog")

-- Rileva la versione di DaVinci Resolve in modo difensivo
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

-- Apre client mail con privacy notice e simultaneamente apre PayPal
local function reportBug(scriptName, version)
    LogManager:info("Config.lua", "Segnalazione bug aperta - " .. scriptName .. " v" .. version)

    -- Mostra privacy notice e template
    BugReportDialog:show(scriptName, version)

    -- Tenta di aprire il client email
    local ok = pcall(function()
        BugReportDialog:sendEmail(scriptName, version)
    end)

    if ok then
        LogManager:info("Config.lua", "Bug report - client email aperto")
    else
        LogManager:warn("Config.lua", "Bug report - errore apertura client email")
    end

    -- Apri PayPal
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('start "" "https://paypal.me/acoffeefortom"')
    else
        os.execute('open "https://paypal.me/acoffeefortom"')
    end
end

-- ============================================================
-- PERCORSO CONFIG
-- ============================================================
-- getConfigPath() → string — Ritorna il path assoluto del file JSON di configurazione (cross-platform).
-- FIX v1.2.6: usa uname -s per rilevare macOS invece di io.open su directory,
-- che in Resolve 20/21 embedded Lua può restituire NIL su macOS Sonoma.
local function getConfigPath()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\repertoire_db.json"
    end
    local home = os.getenv("HOME") or "."
    local h = io.popen("uname -s 2>/dev/null")
    local osname = h and h:read("*a") or ""
    if h then h:close() end
    if osname:match("Darwin") then
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_db.json"
    else
        return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_db.json"
    end
end

-- mkdirForPath: crea la directory padre del path se non esiste (cross-platform).
local function mkdirForPath(path)
    local sep = package.config:sub(1,1)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if not dir then return end
    if sep == "\\" then
        os.execute('mkdir "' .. dir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
end

-- ============================================================
-- LETTURA / SCRITTURA JSON
-- ============================================================
-- loadDB() → table — Legge e decodifica il JSON delle banche dati; ritorna {} se assente o corrotto.
local function loadDB()
    local path = getConfigPath()
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*all")
    f:close()
    local data, _, err = json.decode(content)
    if err then print("loadDB error: " .. tostring(err)) return {} end
    local result = data or {}
    LogManager:info("Config.lua", "Database JSON caricato - " .. #result .. " banche dati trovate")
    return result
end

-- saveDB(db) → bool — Serializza e scrive il DB su disco; ritorna true se riuscito.
local function saveDB(db)
    local path = getConfigPath()
    mkdirForPath(path)
    local f = io.open(path, "w")
    if not f then
        LogManager:error("Config.lua", "Impossibile salvare configurazione - permessi insufficienti")
        return false
    end
    f:write(json.encode(db, { indent = true }))
    f:close()
    LogManager:info("Config.lua", "Configurazione salvata su disk")
    return true
end

-- ============================================================
-- IMPORTAZIONE JSON
-- ============================================================
-- importFromJSON(path) → table|nil, string|nil — Legge un file JSON esterno e ritorna la lista banche dati o nil, errMsg.
local function importFromJSON(path)
    local f = io.open(path, "r")
    if not f then return nil, "File non trovato: " .. path end
    local content = f:read("*all")
    f:close()
    local data, _, err = json.decode(content)
    if err then
        LogManager:error("Config.lua", "Errore importazione JSON: " .. err)
        return nil, "JSON non valido: " .. err
    end
    if type(data) ~= "table" then return nil, "Formato JSON non valido" end
    LogManager:info("Config.lua", "Import JSON completato - " .. #data .. " banche caricate")
    return data, nil
end

-- ============================================================
-- IMPORTAZIONE CSV
-- ============================================================
-- importFromCSV(path) → table|nil, string|nil — Parsa un file CSV (sep auto-rilevato) e ritorna la lista banche dati o nil, errMsg.
local function importFromCSV(path)
    local f = io.open(path, "r")
    if not f then return nil, "File non trovato: " .. path end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    if #lines < 2 then return nil, "CSV vuoto o senza dati" end

    -- Rileva separatore dalla prima riga non-commento e non-vuota
    local sep = ","
    for _, ln in ipairs(lines) do
        if ln:match("%S") and ln:sub(1,1) ~= "#" then
            sep = ln:find(";") and ";" or ","
            break
        end
    end

    local result = {}
    local headerSkipped = false

    for _, line in ipairs(lines) do
        -- Salta righe vuote e righe commento (iniziano con #)
        if not line:match("%S") or line:sub(1,1) == "#" then
            -- skip
        elseif not headerSkipped then
            headerSkipped = true   -- prima riga non-commento = intestazione, ignorata
        else
            local fields = {}
            for field in (line .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do
                field = field:gsub('^"', ''):gsub('"$', ''):match("^%s*(.-)%s*$")
                table.insert(fields, field)
            end
            local name  = fields[1]
            local model = fields[2]
            local rate  = tonumber(fields[3])
            local block = tonumber(fields[4])
            if name and name ~= "" and model and rate then
                local entry = {
                    name      = name,
                    model     = model,
                    rate      = rate,
                    blockSec  = (model == "A blocchi (custom)") and block or nil,
                    discounts = {},
                }
                local mediaType  = fields[5] or "Video"
                local audioExStr = fields[6] or ""
                entry.mediaType  = (mediaType ~= "") and mediaType or "Video"
                entry.audioExcess = (audioExStr == "true" or audioExStr == "Si" or audioExStr == "1") or nil

                local col = 7
                while fields[col] and fields[col] ~= "" do
                    local thresh = tonumber(fields[col])
                    local pct    = tonumber(fields[col+1])
                    local tipo   = fields[col+2] or "flat"
                    if thresh and pct then
                        local disc = {
                            pct  = pct,
                            type = tipo:lower():find("prog") and "progressive" or "flat",
                        }
                        if model == "A clip" then
                            disc.threshold_clips = math.floor(thresh)
                        else
                            disc.threshold_sec = thresh
                        end
                        table.insert(entry.discounts, disc)
                    end
                    col = col + 3
                end
                table.insert(result, entry)
            end
        end
    end
    if #result == 0 then return nil, "Nessuna voce valida trovata nel CSV" end
    return result, nil
end

-- ============================================================
-- PERCORSO TEMPLATES
-- ============================================================
-- getTemplatesDir() → string — Ritorna il path della cartella Templates per il dialogo di importazione (cross-platform).
local function getTemplatesDir()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\Templates"
    end
    local home = os.getenv("HOME") or "."
    return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/Templates"
end

-- ============================================================
-- UI
-- ============================================================
local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

-- ============================================================
-- TIPO FILE
-- ============================================================
local IMAGE_EXTS = {
    jpg=true, jpeg=true, tif=true, tiff=true, png=true, gif=true,
    bmp=true, dpx=true, exr=true, tga=true, webp=true, psd=true,
    heic=true, heif=true, cr2=true, cr3=true, raw=true, nef=true,
    arw=true, dng=true, rw2=true, orf=true, raf=true,
}

-- isImageClip(clip) → bool — Ritorna true se il MediaPoolItem è un file immagine statica (no video/audio).
local function isImageClip(clip)
    local ok, path = pcall(function()
        return clip:GetClipProperty("File Path") or ""
    end)
    if not ok or not path or path == "" then return false end
    local ext = path:match("%.([^%.]+)$")
    return ext and IMAGE_EXTS[ext:lower()] == true
end

-- ============================================================
-- TAGGA CLIP SELEZIONATE NEL MEDIA POOL
-- ============================================================
-- tagSelectedClips(db) → bool, string — Apre il dialogo di tagging e applica la keyword di banca dati alle clip selezionate nel Media Pool.
local function tagSelectedClips(db)
    local project = app:GetResolve():GetProjectManager():GetCurrentProject()
    if not project then
        return false, "Nessun progetto aperto in DaVinci Resolve."
    end
    local mp = project:GetMediaPool()

    local dlg = disp:AddWindow({
        ID = "TagDlg",
        WindowTitle = "Tagga Clip Selezionate",
        Geometry = { 250, 250, 560, 180 },
        ui:VGroup{
            ui:Label{
                ID   = "LblSel",
                Text = "Seleziona le clip nel Media Pool, poi clicca Applica.",
                MinimumSize = { 520, 20 },
            },
            ui:HGroup{
                ui:ComboBox{ ID="ComboArch", MinimumSize={ 350, 26 } },
                ui:Button{   ID="BtnApplica",  Text="✓  Applica",         MinimumSize={ 120, 28 } },
            },
            ui:HGroup{
                ui:Button{ ID="BtnClearKw",  Text="✕  Rimuovi keyword",  MinimumSize={ 170, 26 } },
                ui:HGap{},
                ui:Button{ ID="BtnTagClose", Text="Chiudi",              MinimumSize={  90, 26 } },
            },
            ui:Label{ ID="LblTagStatus", Text="", WordWrap=true, MinimumSize={520, 36} },
        },
    })

    local combo = dlg:Find("ComboArch")
    for _, entry in ipairs(db) do combo:AddItem(entry.name) end

    -- Legge la selezione corrente al momento del clic, non all'apertura.
    -- In questo modo l'utente può cambiare selezione nel Media Pool senza
    -- dover chiudere e riaprire la finestra.
    local function getCurrentSel()
        local sel = mp:GetSelectedClips()
        if not sel or #sel == 0 then
            dlg:Find("LblTagStatus").Text = "⚠  Nessuna clip selezionata nel Media Pool."
            dlg:Find("LblSel").Text = "Seleziona le clip nel Media Pool, poi clicca Applica."
            return nil
        end
        dlg:Find("LblSel").Text = string.format(
            "%d clip selezionate — scegli la banca dati e clicca Applica.", #sel)
        return sel
    end

    dlg.On.BtnApplica.Clicked = function()
        local sel = getCurrentSel()
        if not sel then return end
        local idx   = dlg:Find("ComboArch").CurrentIndex + 1
        local entry = db[idx]
        if not entry then return end

        local mediaType = entry.mediaType or "Video"
        local needsImage = (mediaType == "Fotografie" or mediaType == "Giornali")

        -- Mappa nomi archivi per identificare keyword di repertorio
        local dbNameSet = {}
        for _, e in ipairs(db) do dbNameSet[e.name] = true end

        local tagged  = 0
        local skipped = {}   -- nomi file incompatibili

        for _, clip in ipairs(sel) do
            -- Verifica compatibilità tipo: Foto/Giornali accettano solo immagini
            if needsImage and not isImageClip(clip) then
                local ok2, name = pcall(function()
                    return clip:GetClipProperty("Clip Name")
                        or clip:GetClipProperty("File Name")
                        or "?"
                end)
                table.insert(skipped, (ok2 and name) or "?")
            else
                -- Leggi keywords esistenti e rimuovi solo quelle di repertorio
                local existing = ""
                pcall(function() existing = clip:GetMetadata("Keywords") or "" end)
                existing = existing:match("^%s*(.-)%s*$")
                local kept = {}
                for tok in (existing .. ";"):gmatch("([^;,\n]*)[;,\n]") do
                    tok = tok:match("^%s*(.-)%s*$")
                    if tok ~= "" and not dbNameSet[tok] then
                        table.insert(kept, tok)
                    end
                end
                table.insert(kept, entry.name)
                local ok = pcall(function()
                    clip:SetMetadata("Keywords", table.concat(kept, ";"))
                end)
                if ok then tagged = tagged + 1 end
            end
        end

        -- Messaggio risultato
        local msg = ""
        if tagged > 0 then
            msg = string.format("✓  %d clip → \"%s\"", tagged, entry.name)
            if tagged < #sel then msg = msg .. "  —" end
        end
        if #skipped > 0 then
            msg = msg .. string.format(
                "  ⚠ %d file video ignorat%s: %s",
                #skipped,
                #skipped == 1 and "o" or "i",
                table.concat(skipped, ", "))
        end
        if tagged == 0 and #skipped == 0 then
            msg = "⚠  Nessuna clip aggiornata."
        elseif tagged > 0 and #skipped == 0 then
            msg = msg .. "  — seleziona il prossimo gruppo."
        end
        dlg:Find("LblTagStatus").Text = msg
    end

    dlg.On.BtnClearKw.Clicked = function()
        local sel = getCurrentSel()
        if not sel then return end
        local dbNameSet = {}
        for _, e in ipairs(db) do dbNameSet[e.name] = true end
        local count = 0
        for _, clip in ipairs(sel) do
            local existing = ""
            pcall(function() existing = clip:GetMetadata("Keywords") or "" end)
            existing = existing:match("^%s*(.-)%s*$")
            local kept = {}
            for tok in (existing .. ";"):gmatch("([^;,\n]*)[;,\n]") do
                tok = tok:match("^%s*(.-)%s*$")
                if tok ~= "" and not dbNameSet[tok] then
                    table.insert(kept, tok)
                end
            end
            pcall(function()
                clip:SetMetadata("Keywords", table.concat(kept, ";"))
            end)
            count = count + 1
        end
        dlg:Find("LblTagStatus").Text =
            string.format("✓  Keyword repertorio rimosse da %d clip  — seleziona il prossimo gruppo.", count)
    end

    dlg.On.BtnTagClose.Clicked = function() disp:ExitLoop() end
    dlg.On.TagDlg.Close        = function() disp:ExitLoop() end

    dlg:Show()
    disp:RunLoop()
    dlg:Hide()

    return true, ""
end

local MODELS         = { "A clip", "Al secondo", "A blocchi (custom)", "Al minuto", "Forfait" }
local MODELS_MEDIA   = { "A clip", "Forfait" }
local MEDIA_TYPES    = { "Video", "Fotografie", "Giornali" }
local DISCOUNT_TYPES = { "Flat (su tutto)", "Progressivo (solo eccedenza)" }

-- modelIndex(name) → number — Ritorna l'indice (1-based) del modello nella lista MODELS, default 1.
local function modelIndex(name)
    for i, v in ipairs(MODELS) do if v == name then return i end end
    return 1
end

-- mediaTypeIndex(name) → number — Ritorna l'indice (1-based) del tipo media in MEDIA_TYPES, default 1 (Video).
local function mediaTypeIndex(name)
    for i, v in ipairs(MEDIA_TYPES) do if v == name then return i end end
    return 1
end

-- secToLabel(sec) → string — Formatta un valore in secondi come stringa leggibile (es. "2m 30s").
local function secToLabel(sec)
    if not sec then return "" end
    local m = math.floor(sec / 60)
    local s = sec % 60
    return m > 0 and string.format("%dm %02ds", m, s) or string.format("%ds", s)
end

-- ── Memory/Configuration helpers ─────────────────────────────────────────────

local function getMemoriesDir()
    local sep = package.config:sub(1,1)
    local dir = getConfigPath():match("^(.+)[/\\][^/\\]+$") or "."
    return dir .. sep .. "memories"
end

local function ensureMemoriesDir()
    local dir = getMemoriesDir()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('mkdir "' .. dir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. dir:gsub('"', '\\"') .. '" 2>/dev/null')
    end
    return dir
end

local function saveMemoryFile(name, data)
    local dir = ensureMemoriesDir()
    local sep = package.config:sub(1,1)
    local path = dir .. sep .. name .. ".json"
    local payload = { version = 1, saved = os.date("%Y-%m-%d %H:%M"), banks = data }
    local f = io.open(path, "w")
    if not f then return false, "Impossibile scrivere il file" end
    f:write(json.encode(payload, { indent = true }))
    f:close()
    return true, nil
end

local function loadMemoryFile(path)
    local f = io.open(path, "r")
    if not f then return nil, "File non trovato" end
    local content = f:read("*all")
    f:close()
    local payload, _, err = json.decode(content)
    if err then return nil, "JSON corrotto: " .. tostring(err) end
    if type(payload) == "table" and payload.banks then
        return payload.banks, nil
    elseif type(payload) == "table" and #payload > 0 then
        return payload, nil
    end
    return nil, "Formato non riconosciuto"
end

local function listMemoryFiles()
    local dir = getMemoriesDir()
    local sep = package.config:sub(1,1)
    local isWin = (sep == "\\")
    local cmd = isWin
        and ('dir /b "' .. dir .. '" 2>nul')
        or  ('find "' .. dir:gsub('"', '\\"') .. '" -maxdepth 1 -name "*.json" 2>/dev/null')
    local files = {}
    local h = io.popen(cmd)
    if h then
        for line in h:lines() do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                local name = line:match("([^/\\]+)%.json$")
                local fullPath = isWin and (dir .. sep .. line) or line
                if name and name ~= "_previous" then
                    local saved, banks = "—", 0
                    local f2 = io.open(fullPath, "r")
                    if f2 then
                        local c = f2:read("*all"); f2:close()
                        local p, _, _ = json.decode(c)
                        if type(p) == "table" then
                            saved = p.saved or "—"
                            banks = p.banks and #p.banks or 0
                        end
                    end
                    table.insert(files, { name = name, saved = saved, banks = banks })
                end
            end
        end
        h:close()
    end
    return files
end

local function previousBackupExists()
    local dir = getMemoriesDir()
    local sep = package.config:sub(1,1)
    local f = io.open(dir .. sep .. "_previous.json", "r")
    if f then f:close(); return true end
    return false
end

-- buildWindow(db) → window — Costruisce e ritorna la finestra principale di configurazione con tutti gli handler.
local function buildWindow(db)
    local win = disp:AddWindow({
        ID = "DBConfig",
        WindowTitle = "RepertoireDB v" .. VERSION .. " — Configurazione  |  © Tommaso Feraboli Film Editor",
        Geometry = { 80, 80, 920, 820 },
        MinimumSize = { 900, 800 },
        ui:VGroup{
            ui:HGroup{
                ui:Label{ Text = "RepertoireDB v" .. VERSION,
                    Font = ui:Font{ PixelSize = 20 },
                    StyleSheet = "color: #DCDCDC;" },
                ui:HGap{},
                ui:VGroup{
                    ui:Label{ Text = "© Tommaso Feraboli Film Editor",
                        Alignment = { AlignRight = true },
                        Font = ui:Font{ PixelSize = 13 },
                        StyleSheet = "color: #D2D2D2;" },
                    ui:Label{ Text = "MIT License",
                        Alignment = { AlignRight = true },
                        Font = ui:Font{ PixelSize = 10, Italic = true },
                        StyleSheet = "color: #828282; margin-top: 0px;" },
                },
            },

            ui:TabBar{ ID="MainTabs" },
            ui:VGroup{ ID="PaneBanche",
            ui:HGroup{
                ui:Button{ ID="BtnSearch", Text="🔍", MinimumSize={30,26},
                    ToolTip="Cerca per nome o tipo media",
                    StyleSheet = "QPushButton { border-radius: 4px; font-size: 15px; }" },
                ui:LineEdit{ ID="SearchField", PlaceholderText="Cerca banca…",
                    MinimumSize={200,26}, Hidden=true },
                ui:HGap{},
            },
            ui:Tree{
                ID = "DBList",
                RootIsDecorated = false,
                AlternatingRowColors = true,
                SelectionMode = "SingleSelection",
                SortingEnabled = true,
                MinimumSize = { 800, 270 },
            },
            ui:HGroup{
                ui:Button{ ID="BtnNew",         Text="+ Nuova",           MinimumSize={110,28} },
                ui:Button{ ID="BtnEdit",        Text="✎ Modifica",        MinimumSize={110,28}, Enabled=false },
                ui:Button{ ID="BtnDelete",      Text="Elimina",           MinimumSize={100,28} },
                ui:Button{ ID="BtnImport",      Text="Importa JSON/CSV…", MinimumSize={160,28} },
                ui:Button{ ID="BtnExportCSV",   Text="Esporta CSV",       MinimumSize={120,28} },
                ui:Button{ ID="BtnTag", Text="Tagga Clip Selezionate", MinimumSize={190,28} },
                ui:HGap{},
            },

            ui:Label{ Text = "──────────────────────────────────────────────────────────────────" },

            ui:HGroup{
                ui:Label{ Text="Nome banca dati:", MinimumSize={140,20} },
                ui:LineEdit{ ID="FieldName", PlaceholderText="Inserisci nome nuova banca", MinimumSize={380,24} },
            },
            ui:HGroup{
                ui:Label{ Text="Tipo media:", MinimumSize={140,20} },
                ui:ComboBox{ ID="FieldType", MinimumSize={200,24} },
                ui:HGap{},
            },
            ui:HGroup{
                ui:Label{ Text="Modello pricing:", MinimumSize={140,20} },
                ui:ComboBox{ ID="FieldModel", MinimumSize={200,24} },
                ui:Label{ Text="Durata blocco (sec):", MinimumSize={130,20} },
                ui:SpinBox{ ID="FieldBlock", Minimum=1, Maximum=3600, Value=30, MinimumSize={70,24} },
            },
            ui:HGroup{
                ui:Label{ Text="Utilizzo minimo (sec):", MinimumSize={140,20} },
                ui:SpinBox{ ID="FieldUtilMin", Minimum=0, Maximum=86400, Value=0, MinimumSize={80,24} },
                ui:Label{ Text="(0 = nessun minimo — si fattura almeno questo utilizzo anche se l'effettivo è inferiore)",
                    MinimumSize={420,20}, StyleSheet="color:#AAAAAA; font-size:9px;" },
                ui:HGap{},
            },
            ui:HGroup{
                ui:Label{ Text="Tariffa (€):", MinimumSize={140,20} },
                ui:LineEdit{ ID="FieldRate", PlaceholderText="es. 5300.00", MinimumSize={120,24} },
                ui:Label{ Text="(per unità del modello scelto)   " },
                ui:CheckBox{ ID="ChkNoRate", Text="Tariffa da definire", Checked=false },
                ui:HGap{},
                ui:CheckBox{ ID="ChkAudioExcess", Text="Calcola audio eccedente", Checked=false,
                    ToolTip="Se attivo, i secondi audio senza copertura video vengono fatturati al 50% della tariffa" },
            },

            ui:Label{ Text = "── Sconti ─────────────────────────────────────────────────────" },
            ui:Tree{
                ID = "DiscountList",
                RootIsDecorated = false,
                AlternatingRowColors = true,
                SelectionMode = "SingleSelection",
                MinimumSize = { 800, 85 },
            },
            ui:HGroup{
                ui:Label{ ID="LblDscThreshold", Text="Soglia (sec):", MinimumSize={90,20} },
                ui:SpinBox{ ID="DscThreshold", Minimum=1, Maximum=36000, Value=180, MinimumSize={80,24} },
                ui:Label{ Text="Sconto %:", MinimumSize={70,20} },
                ui:SpinBox{ ID="DscPct", Minimum=1, Maximum=100, Value=15, MinimumSize={70,24} },
                ui:Label{ Text="Tipo:", MinimumSize={40,20} },
                ui:ComboBox{ ID="DscType", MinimumSize={210,24} },
                ui:Button{ ID="BtnDscAdd",    Text="+ Aggiungi sconto", MinimumSize={130,28} },
                ui:Button{ ID="BtnDscDelete", Text="Elimina",    MinimumSize={80,28} },
            },

            ui:Label{ Text = "──────────────────────────────────────────────────────────────────" },

            ui:HGroup{
                ui:Button{ ID="BtnSave",   Text="Salva modifiche", MinimumSize={160,32} },
                ui:Button{ ID="BtnCancel", Text="Annulla",         MinimumSize={100,32} },
                ui:Button{ ID="BtnOpenCalculator", Text="⏭️  Apri Calcolatore", MinimumSize={180,32} },
                ui:HGap{},
                ui:Label{ ID="LblStatus", Text="" },
                ui:VGroup{ Spacing=1,
                    ui:Button{ ID="BtnReadme", Text="📖", MinimumSize={80,52},
                        ToolTip="Apre il file README",
                        StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #8B7B1A,stop:1 #5A4E0A);color:#FFE97A;border-radius:5px;border:1px solid #5A4E0A;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #A08A20,stop:1 #8B7B1A);}]] },
                    ui:Label{ Text="Guida", Alignment={AlignHCenter=true},
                        StyleSheet="color:#8B7B1A; font-size:10px; margin:0;" },
                },
                ui:VGroup{ Spacing=1,
                    ui:Button{ ID="BtnPayPal", Text="☕", MinimumSize={80,52},
                        ToolTip="Supporta il progetto su PayPal",
                        StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #2196C0,stop:1 #1565A0);color:#FFFFFF;border-radius:5px;border:1px solid #1565A0;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #2AA8D8,stop:1 #2196C0);}]] },
                    ui:Label{ Text="Offrimi un caffè", Alignment={AlignHCenter=true},
                        StyleSheet="color:#2196C0; font-size:10px; margin:0;" },
                },
                ui:VGroup{ Spacing=1,
                    ui:Button{ ID="BtnBug", Text="🐛", MinimumSize={80,52},
                        ToolTip="Invia una segnalazione bug a tomfilmeditor.tools@gmail.com",
                        StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #B03020,stop:1 #7A1E10);color:#FFFFFF;border-radius:5px;border:1px solid #7A1E10;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #C84030,stop:1 #B03020);}]] },
                    ui:Label{ Text="Riporta bug", Alignment={AlignHCenter=true},
                        StyleSheet="color:#B03020; font-size:10px; margin:0;" },
                },
            },
            }, -- PaneBanche
            ui:VGroup{ ID="PaneMemorie", Hidden=true,
                ui:HGroup{
                    ui:Label{ Text="Configurazioni salvate:",
                        Font=ui:Font{ Bold=true },
                        StyleSheet="color:#DCDCDC; font-size:13px;" },
                    ui:HGap{},
                    ui:Button{ ID="BtnMemPrev", Text="↩  Ripristina precedente",
                        MinimumSize={210,28},
                        ToolTip="Ripristina la configurazione precedente all'ultimo caricamento",
                        Enabled=false },
                },
                ui:Tree{
                    ID = "MemoryList",
                    RootIsDecorated = false,
                    AlternatingRowColors = true,
                    SelectionMode = "SingleSelection",
                    MinimumSize = { 800, 500 },
                },
                ui:Label{ Text = "──────────────────────────────────────────────────────────────────" },
                ui:HGroup{
                    ui:Label{ Text="Nome:", MinimumSize={60,20} },
                    ui:LineEdit{ ID="MemoryName", PlaceholderText="Nome configurazione…", MinimumSize={340,26} },
                    ui:HGap{},
                    ui:Button{ ID="BtnMemSave", Text="💾  Salva configurazione attuale", MinimumSize={250,28} },
                },
                ui:HGroup{
                    ui:Button{ ID="BtnMemLoad",   Text="📂  Carica selezionata",  MinimumSize={180,32} },
                    ui:Button{ ID="BtnMemDelete", Text="🗑  Elimina selezionata", MinimumSize={180,32} },
                    ui:HGap{},
                    ui:Label{ ID="LblMemStatus", Text="" },
                },
            },
        },
    })

    -- Popola ComboBox
    local combo = win:Find("FieldModel")
    for _, m in ipairs(MODELS) do combo:AddItem(m) end
    local comboType = win:Find("FieldType")
    for _, t in ipairs(MEDIA_TYPES) do comboType:AddItem(t) end

    -- Lista corrente del ComboBox FieldModel (varia per tipo media)
    local currentModelList = MODELS

    -- Ricostruisce il ComboBox FieldModel con la lista corretta per il tipo media.
    -- Preserva la selezione se il modello esiste nella nuova lista.
    local function rebuildModelCombo(isMedia)
        local combo2   = win:Find("FieldModel")
        local prevName = currentModelList[combo2.CurrentIndex + 1] or "A clip"
        local newList  = isMedia and MODELS_MEDIA or MODELS
        combo2:Clear()
        for _, m in ipairs(newList) do combo2:AddItem(m) end
        currentModelList = newList
        for i, m in ipairs(newList) do
            if m == prevName then combo2.CurrentIndex = i - 1; return end
        end
        combo2.CurrentIndex = 0
    end
    local comboD = win:Find("DscType")
    for _, t in ipairs(DISCOUNT_TYPES) do comboD:AddItem(t) end

    local currentDiscounts   = {}
    local editingIndex        = nil
    local editingDiscountIdx  = nil
    local filterText          = ""      -- testo ricerca corrente

    local function refreshDiscountList()
        local tree = win:Find("DiscountList")
        tree:Clear()
        local hdr = tree:NewItem()
        hdr.Text[0] = "Soglia"
        hdr.Text[1] = "Sconto %"
        hdr.Text[2] = "Tipo"
        tree:SetHeaderItem(hdr)
        tree.ColumnCount = 3
        tree:SetColumnWidth(0, 220)
        tree:SetColumnWidth(1, 120)
        tree:SetColumnWidth(2, 320)
        for _, d in ipairs(currentDiscounts) do
            local it = tree:NewItem()
            if d.threshold_clips then
                it.Text[0] = "Oltre " .. d.threshold_clips .. " clip"
            else
                it.Text[0] = "Oltre " .. secToLabel(d.threshold_sec)
            end
            it.Text[1] = tostring(d.pct) .. "%"
            it.Text[2] = (d.type == "progressive") and "Progressivo (solo eccedenza)" or "Flat (su tutto)"
            tree:AddTopLevelItem(it)
        end
    end

    -- Aggiorna etichetta soglia e default SpinBox in base al modello corrente
    local function updateDscThresholdUI()
        local typeWidget = win:Find("FieldType")
        local typeIdx    = typeWidget and typeWidget.CurrentIndex or 0
        local mt         = MEDIA_TYPES[typeIdx + 1] or "Video"
        local selModel   = currentModelList[win:Find("FieldModel").CurrentIndex + 1]
        local isClip     = (mt ~= "Video") or
                           (selModel == "A clip") or (selModel == "Forfait")
        local lbl = win:Find("LblDscThreshold")
        if lbl then
            lbl.Text = isClip and "Soglia (clip):" or "Soglia (sec):"
        end
    end

    local function refreshTree()
        local tree = win:Find("DBList")
        tree:Clear()

        local hdr = tree:NewItem()
        hdr.Text[0] = "Nome"
        hdr.Text[1] = "Tipo"
        hdr.Text[2] = "Modello"
        hdr.Text[3] = "Blocco"
        hdr.Text[4] = "Util.Min."
        hdr.Text[5] = "Tariffa €"
        hdr.Text[6] = "Sconti"
        hdr.Text[7] = "Audio Ecc."
        tree:SetHeaderItem(hdr)
        tree.ColumnCount = 8
        tree:SetColumnWidth(0, 200)
        tree:SetColumnWidth(1, 90)
        tree:SetColumnWidth(2, 140)
        tree:SetColumnWidth(3, 55)
        tree:SetColumnWidth(4, 70)
        tree:SetColumnWidth(5, 85)
        tree:SetColumnWidth(6, 140)
        tree:SetColumnWidth(7, 75)

        -- Filtra per testo (case-insensitive, su nome e tipo media)
        local lo = filterText ~= "" and string.lower(filterText) or nil
        local sortedDB = {}
        for _, e in ipairs(db) do
            if not lo or
               string.lower(e.name):find(lo, 1, true) or
               string.lower(e.mediaType or "Video"):find(lo, 1, true) then
                table.insert(sortedDB, e)
            end
        end
        -- Ordinamento gestito nativamente da Qt (SortingEnabled=true sul Tree)

        for _, e in ipairs(sortedDB) do
            local it = tree:NewItem()
            it.Text[0] = e.name
            it.Text[1] = e.mediaType or "Video"
            it.Text[2] = e.model
            it.Text[3] = (e.model == "A blocchi (custom)") and tostring(e.blockSec or 30) or "—"
            it.Text[4] = (e.utilMin and e.utilMin > 0) and (tostring(e.utilMin) .. "s") or "—"
            it.Text[5] = e.rate and string.format("%.2f", e.rate) or "—"
            local nd = e.discounts and #e.discounts or 0
            it.Text[6] = nd > 0 and (nd .. " soglia" .. (nd > 1 and "e" or "")) or "—"
            it.Text[7] = e.audioExcess and "✓" or "—"
            tree:AddTopLevelItem(it)
        end
    end

    local function savePreviousBackup()
        local dir = ensureMemoriesDir()
        local sep = package.config:sub(1,1)
        local path = dir .. sep .. "_previous.json"
        local payload = { version = 1, saved = os.date("%Y-%m-%d %H:%M"), banks = db }
        local f = io.open(path, "w")
        if f then f:write(json.encode(payload, { indent = true })); f:close() end
    end

    local function refreshMemoryList()
        local tree = win:Find("MemoryList")
        tree:Clear()
        local hdr = tree:NewItem()
        hdr.Text[0] = "Nome"
        hdr.Text[1] = "Salvata il"
        hdr.Text[2] = "Banche"
        tree:SetHeaderItem(hdr)
        tree.ColumnCount = 3
        tree:SetColumnWidth(0, 430)
        tree:SetColumnWidth(1, 220)
        tree:SetColumnWidth(2, 80)
        local mems = listMemoryFiles()
        for _, m in ipairs(mems) do
            local it = tree:NewItem()
            it.Text[0] = m.name
            it.Text[1] = m.saved
            it.Text[2] = tostring(m.banks)
            tree:AddTopLevelItem(it)
        end
        win:Find("BtnMemPrev").Enabled = previousBackupExists()
    end

    refreshTree()
    refreshDiscountList()

    -- Inizializza tab
    local tabs = win:Find("MainTabs")
    tabs:AddTab("📋  Banche Dati")
    tabs:AddTab("💾  Memorie")

    -- setFormReadOnly(bool): abilita/disabilita tutti i campi del form.
    -- readonly=true  → visione (click su riga lista); readonly=false → modifica/nuova banca.
    local function setFormReadOnly(readonly)
        local en = not readonly
        win:Find("FieldName").Enabled       = en
        win:Find("ChkNoRate").Enabled       = en
        win:Find("FieldRate").Enabled       = en and not win:Find("ChkNoRate").Checked
        win:Find("FieldBlock").Enabled      = en
        win:Find("FieldUtilMin").Enabled    = en
        win:Find("ChkAudioExcess").Enabled  = en
        local typeWidget = win:Find("FieldType")
        if typeWidget then
            typeWidget.Enabled = en
        end
        win:Find("FieldModel").Enabled = en
        win:Find("DscThreshold").Enabled  = en
        win:Find("DscPct").Enabled        = en
        win:Find("DscType").Enabled       = en
        win:Find("BtnDscAdd").Enabled     = en
        win:Find("BtnDscDelete").Enabled  = en
        win:Find("BtnSave").Enabled       = en
        win:Find("BtnCancel").Enabled     = en
    end

    local function clearForm()
        win:Find("FieldName").Text          = ""
        win:Find("FieldRate").Text          = ""
        win:Find("ChkNoRate").Checked       = false
        win:Find("ChkAudioExcess").Checked  = false
        win:Find("FieldModel").CurrentIndex = 0
        win:Find("FieldBlock").Value        = 30
        win:Find("FieldUtilMin").Value      = 0
        -- FieldType: reset con fallback sicuro
        local typeWidget = win:Find("FieldType")
        if typeWidget then typeWidget.CurrentIndex = 0 end
        editingIndex       = nil
        editingDiscountIdx = nil
        currentDiscounts   = {}
        refreshDiscountList()
        updateDscThresholdUI()
        win:Find("LblStatus").Text = ""
        -- Nessuna banca selezionata: form pronta per nuova voce (editabile)
        setFormReadOnly(false)
        local btnEdit = win:Find("BtnEdit")
        if btnEdit then btnEdit.Enabled = false end
    end

    local function loadFormFromIndex(idx)
        local e = db[idx]
        if not e then return end
        win:Find("FieldName").Text = e.name
        local noRate = (e.rate == nil)
        win:Find("ChkNoRate").Checked = noRate
        win:Find("FieldRate").Enabled = not noRate
        win:Find("FieldRate").Text = noRate and "" or string.format("%.2f", e.rate)
        local tiIdx = mediaTypeIndex(e.mediaType or "Video") - 1
        local typeWidget = win:Find("FieldType")
        if typeWidget then typeWidget.CurrentIndex = tiIdx end
        rebuildModelCombo(tiIdx > 0)
        local targetModel = e.model or "A clip"
        local comboModel = win:Find("FieldModel")
        local found = false
        for i, m in ipairs(currentModelList) do
            if m == targetModel then comboModel.CurrentIndex = i - 1; found = true; break end
        end
        if not found then comboModel.CurrentIndex = 0 end
        win:Find("FieldBlock").Value   = e.blockSec or 30
        win:Find("FieldUtilMin").Value = e.utilMin  or 0
        win:Find("ChkAudioExcess").Checked = e.audioExcess == true
        currentDiscounts = {}
        if e.discounts then
            for _, d in ipairs(e.discounts) do
                local disc = { pct = d.pct, type = d.type or "flat" }
                if d.threshold_clips then
                    disc.threshold_clips = d.threshold_clips
                else
                    disc.threshold_sec = d.threshold_sec
                end
                table.insert(currentDiscounts, disc)
            end
        end
        refreshDiscountList()
        updateDscThresholdUI()
        editingIndex = idx
        -- Caricamento da selezione: form in sola lettura fino a click su Modifica
        setFormReadOnly(true)
        local btnEdit = win:Find("BtnEdit")
        if btnEdit then btnEdit.Enabled = true end
    end

    win.On.DBList.CurrentItemChanged = function(ev)
        local sel = win:Find("DBList"):CurrentItem()
        if sel then
            for i, e in ipairs(db) do
                if e.name == sel.Text[0] then loadFormFromIndex(i) break end
            end
        end
    end

    win.On.BtnEdit.Clicked = function(ev)
        if editingIndex then
            setFormReadOnly(false)
            win:Find("LblStatus").Text = "Modifica abilitata — premi Salva per confermare."
        end
    end

    win.On.BtnSearch.Clicked = function(ev)
        local sf = win:Find("SearchField")
        sf.Hidden = not sf.Hidden
        if sf.Hidden then
            sf.Text = ""
            filterText = ""
            refreshTree()
        end
    end

    win.On.SearchField.TextChanged = function(ev)
        filterText = win:Find("SearchField").Text or ""
        refreshTree()
    end

    win.On.BtnReadme.Clicked = function(ev)
        local sep  = package.config:sub(1,1)
        local dir  = getConfigPath():match("^(.+)[/\\][^/\\]+$") or "."
        local path = dir .. sep .. "RepertoireDB_README.txt"
        if sep == "\\" then
            os.execute('start "" "' .. path .. '"')
        else
            os.execute('open "' .. path .. '"')
        end
    end

    win.On.BtnPayPal.Clicked = function(ev)
        local sep = package.config:sub(1,1)
        if sep == "\\" then
            os.execute('start "" "https://paypal.me/acoffeefortom"')
        else
            os.execute('open "https://paypal.me/acoffeefortom"')
        end
    end

    win.On.DiscountList.CurrentItemChanged = function(ev)
        local sel = win:Find("DiscountList"):CurrentItem()
        if sel then
            for i, d in ipairs(currentDiscounts) do
                local label = d.threshold_clips and ("Oltre " .. d.threshold_clips .. " clip")
                                               or  ("Oltre " .. secToLabel(d.threshold_sec))
                if label == sel.Text[0] then
                    editingDiscountIdx = i
                    win:Find("DscThreshold").Value   = d.threshold_clips or d.threshold_sec or 1
                    win:Find("DscPct").Value          = d.pct
                    win:Find("DscType").CurrentIndex  = (d.type == "progressive") and 1 or 0
                    break
                end
            end
        end
    end

    -- Aggiorna etichetta soglia e stato FieldModel in tempo reale
    win.On.FieldModel.CurrentIndexChanged = function(ev)
        updateDscThresholdUI()
    end
    win.On.FieldType.CurrentIndexChanged = function(ev)
        local isMedia = win:Find("FieldType").CurrentIndex > 0
        rebuildModelCombo(isMedia)
        updateDscThresholdUI()
    end

    win.On.ChkNoRate.Clicked = function(ev)
        local checked = win:Find("ChkNoRate").Checked
        win:Find("FieldRate").Enabled = not checked
        if checked then win:Find("FieldRate").Text = "" end
    end

    win.On.BtnNew.Clicked = function(ev) clearForm() end

    win.On.BtnDelete.Clicked = function(ev)
        if editingIndex then
            table.remove(db, editingIndex)
            saveDB(db)
            clearForm()
            refreshTree()
            win:Find("LblStatus").Text = "Eliminata."
        else
            win:Find("LblStatus").Text = "⚠ Seleziona prima una voce dalla lista."
        end
    end

    -- ── Logica di salvataggio condivisa ──────────────────────────
    -- resetForm=true  → chiamata da BtnSave (pulisce il form dopo)
    -- resetForm=false → chiamata da BtnDscAdd/Delete (mantiene il form aperto)
    -- Restituisce true se il salvataggio è riuscito, false altrimenti.
    local function doSave(resetForm, statusOnOk)
        local name  = win:Find("FieldName").Text
        local rateS = win:Find("FieldRate").Text

        if name == "" then
            win:Find("LblStatus").Text = "⚠ Inserisci un nome."
            return false
        end
        local noRate = win:Find("ChkNoRate").Checked
        local rate   = nil
        if not noRate then
            rate = tonumber(rateS)
            if not rate then
                win:Find("LblStatus").Text = "⚠ Tariffa non valida (usa il punto come decimale)."
                return false
            end
        end

        local typeWidget = win:Find("FieldType")
        local typeIdx    = typeWidget and typeWidget.CurrentIndex or 0
        local mediaType  = MEDIA_TYPES[typeIdx + 1] or "Video"
        local model = currentModelList[win:Find("FieldModel").CurrentIndex + 1] or "A clip"
        local block   = win:Find("FieldBlock").Value
        local utilMin = win:Find("FieldUtilMin").Value

        local audioExcess = win:Find("ChkAudioExcess").Checked
        local entry = {
            name        = name,
            mediaType   = mediaType,
            model       = model,
            rate        = rate,
            blockSec    = (model == "A blocchi (custom)") and block or nil,
            utilMin     = (utilMin and utilMin > 0) and utilMin or nil,
            discounts   = #currentDiscounts > 0 and currentDiscounts or nil,
            audioExcess = audioExcess or nil,
        }

        if editingIndex then
            db[editingIndex] = entry
        else
            for _, e in ipairs(db) do
                if e.name == name then
                    win:Find("LblStatus").Text = "⚠ Nome già esistente."
                    return false
                end
            end
            table.insert(db, entry)
            -- Dopo il primo salvataggio, imposta editingIndex
            -- così i salvataggi successivi (da BtnDscAdd) aggiornano la stessa banca
            for i, e in ipairs(db) do
                if e.name == name then editingIndex = i break end
            end
        end

        local saved = saveDB(db)
        refreshTree()
        if resetForm then clearForm() end
        win:Find("LblStatus").Text = saved
            and (statusOnOk or "✓ Salvato.")
            or  "⚠ Errore scrittura file."
        return saved
    end

    win.On.BtnDscAdd.Clicked = function(ev)
        local thresh = win:Find("DscThreshold").Value
        local pct    = win:Find("DscPct").Value
        local tipo   = win:Find("DscType").CurrentIndex == 1 and "progressive" or "flat"

        -- Determina se il modello usa soglie per clip o per secondi
        local typeWidget = win:Find("FieldType")
        local typeIdx    = typeWidget and typeWidget.CurrentIndex or 0
        local mt         = MEDIA_TYPES[typeIdx + 1] or "Video"
        local selModel2  = currentModelList[win:Find("FieldModel").CurrentIndex + 1]
        local isClip     = (mt ~= "Video") or
                           (selModel2 == "A clip") or (selModel2 == "Forfait")

        -- Verifica duplicati
        for _, d in ipairs(currentDiscounts) do
            if (d.threshold_clips or d.threshold_sec) == thresh then
                win:Find("LblStatus").Text = "⚠ Soglia già presente."
                return
            end
        end

        local disc = { pct=pct, type=tipo }
        if isClip then
            disc.threshold_clips = thresh
        else
            disc.threshold_sec = thresh
        end
        table.insert(currentDiscounts, disc)
        table.sort(currentDiscounts, function(a, b)
            return (a.threshold_clips or a.threshold_sec or 0) <
                   (b.threshold_clips or b.threshold_sec or 0)
        end)
        refreshDiscountList()
        doSave(false, "✓ Sconto aggiunto e salvato.")
    end

    win.On.BtnDscDelete.Clicked = function(ev)
        if editingDiscountIdx then
            table.remove(currentDiscounts, editingDiscountIdx)
            editingDiscountIdx = nil
            refreshDiscountList()
            -- Salva subito la banca senza lo sconto eliminato
            if editingIndex then
                doSave(false, "✓ Sconto rimosso e salvato.")
            end
        else
            win:Find("LblStatus").Text = "⚠ Seleziona uno sconto dalla lista."
        end
    end

    win.On.BtnSave.Clicked = function(ev)
        local success, errMsg = pcall(function()
            doSave(true, "✓ Salvato.")
        end)
        if not success then
            print("RepertoireDB Config — BtnSave error: " .. tostring(errMsg))
            win:Find("LblStatus").Text = "⚠ Errore interno (vedi Console Resolve)"
        end
    end

    win.On.BtnCancel.Clicked = function(ev) clearForm() end

    win.On.BtnOpenCalculator.Clicked = function(ev)
        local sep = package.config:sub(1,1)
        local configPath = getConfigPath()
        local scriptDir = configPath:match("^(.+)" .. sep .. "[^" .. sep .. "]+$") or "."
        local calculatorPath = scriptDir .. sep .. "RepertoireDB_Calculator.lua"
        dofile(calculatorPath)
        disp:ExitLoop()
    end

    win.On.BtnBug.Clicked = function(ev)
        reportBug("RepertoireDB_Config.lua", VERSION)
    end

    win.On.BtnImport.Clicked = function(ev)
        local path = fu:RequestFile(getTemplatesDir(), "", 0)
        if not path or path == "" then return end
        local data, err
        if path:lower():match("%.json$") then
            data, err = importFromJSON(path)
        elseif path:lower():match("%.csv$") then
            data, err = importFromCSV(path)
        else
            win:Find("LblStatus").Text = "⚠ Formato non supportato (usa .json o .csv)" return
        end
        if err then
            win:Find("LblStatus").Text = "⚠ " .. err return
        end

        -- Dialog selezione modalità importazione
        local dlg = disp:AddWindow({
            ID = "ImportDlg",
            WindowTitle = "Modalità importazione",
            Geometry = { 300, 300, 420, 200 },
            ui:VGroup{
                ui:Label{ Text = "Come vuoi importare le " .. #data .. " banche dati?", MinimumSize={380,24} },
                ui:Label{ Text = "" },
                ui:Button{ ID="BtnModeAdd",     Text="Aggiungi nuove (salta duplicati)",        MinimumSize={380,32} },
                ui:Button{ ID="BtnModeUpdate",  Text="Aggiorna esistenti (sovrascrive duplicati)", MinimumSize={380,32} },
                ui:Button{ ID="BtnModeReplace", Text="Sostituisci tutto (cancella e reimporta)", MinimumSize={380,32} },
                ui:Button{ ID="BtnModeCancel",  Text="Annulla",                                  MinimumSize={380,28} },
            },
        })

        local importMode = nil

        dlg.On.BtnModeAdd.Clicked     = function() importMode = "add"     disp:ExitLoop() end
        dlg.On.BtnModeUpdate.Clicked  = function() importMode = "update"  disp:ExitLoop() end
        dlg.On.BtnModeReplace.Clicked = function() importMode = "replace" disp:ExitLoop() end
        dlg.On.BtnModeCancel.Clicked  = function() importMode = nil       disp:ExitLoop() end
        dlg.On.ImportDlg.Close        = function() importMode = nil       disp:ExitLoop() end

        dlg:Show()
        disp:RunLoop()
        dlg:Hide()

        if not importMode then return end

        local added, updated = 0, 0

        if importMode == "replace" then
            -- Sostituisce tutto
            for i = #db, 1, -1 do table.remove(db, i) end
            for _, e in ipairs(data) do table.insert(db, e) end
            added = #data

        elseif importMode == "update" then
            -- Aggiorna esistenti, aggiunge nuove
            for _, newEntry in ipairs(data) do
                local found = false
                for i, existing in ipairs(db) do
                    if existing.name == newEntry.name then
                        db[i] = newEntry
                        updated = updated + 1
                        found = true break
                    end
                end
                if not found then table.insert(db, newEntry) added = added + 1 end
            end

        else
            -- Aggiungi solo nuove
            for _, newEntry in ipairs(data) do
                local found = false
                for _, existing in ipairs(db) do
                    if existing.name == newEntry.name then found = true break end
                end
                if not found then table.insert(db, newEntry) added = added + 1 end
            end
        end

        saveDB(db)
        refreshTree()
        clearForm()
        win:Find("LblStatus").Text = string.format(
            "✓ Aggiunte: %d  Aggiornate: %d  Totale DB: %d", added, updated, #db)
    end

    win.On.BtnExportCSV.Clicked = function(ev)
        if #db == 0 then
            win:Find("LblStatus").Text = "⚠ Nessuna banca dati da esportare."
            return
        end

        local home    = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
        local desktop = home .. "/Desktop"
        local dir = fu:RequestDir(desktop)
        if not dir or dir == "" then return end
        if not dir:match("[/\\]$") then dir = dir .. "/" end

        local filename = "RepertoireDB_Archivi_" .. os.date("%Y%m%d_%H%M%S") .. ".csv"
        local path = dir .. filename
        local f = io.open(path, "w")
        if not f then
            win:Find("LblStatus").Text = "⚠ Impossibile scrivere in: " .. dir
            return
        end

        f:write("\xEF\xBB\xBF")  -- BOM UTF-8
        -- Righe commento (ignorate dall'import)
        f:write("# RepertoireDB v" .. VERSION .. " — Esportazione Archivi\n")
        f:write("# Generato: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        -- Intestazione colonne (ignorata dall'import come prima riga non-commento)
        f:write("Nome,Modello,Tariffa (EUR),Durata Blocco (sec),Tipo,Audio Eccedente,Soglia1,Sconto1%,TipoSconto1,...\n")

        for _, e in ipairs(db) do
            local rateStr  = e.rate and string.format("%.4f", e.rate) or ""
            local blockStr = (e.model == "A blocchi (custom)") and tostring(e.blockSec or 30) or ""
            local audioStr = e.audioExcess and "true" or "false"
            local mediaStr = e.mediaType or "Video"

            local line = string.format('"%s","%s","%s","%s","%s","%s"',
                e.name, e.model or "", rateStr, blockStr, mediaStr, audioStr)

            if e.discounts and #e.discounts > 0 then
                for _, d in ipairs(e.discounts) do
                    local thresh
                    if e.model == "A clip" then
                        thresh = tostring(d.threshold_clips or 0)
                    else
                        thresh = tostring(d.threshold_sec or 0)
                    end
                    local tipoStr = (d.type == "progressive") and "progressive" or "flat"
                    line = line .. string.format(',"%s","%.4f","%s"', thresh, d.pct or 0, tipoStr)
                end
            end

            f:write(line .. "\n")
        end

        f:close()
        win:Find("LblStatus").Text = "✓ CSV esportato: " .. path
    end

    win.On.BtnTag.Clicked = function(ev)
        if #db == 0 then
            win:Find("LblStatus").Text = "⚠ Nessuna banca dati configurata." return
        end
        local ok, msg = tagSelectedClips(db)
        if not ok then
            win:Find("LblStatus").Text = "⚠ " .. msg
        end
    end

    win.On.MainTabs.CurrentChanged = function(ev)
        local idx = win:Find("MainTabs").CurrentIndex
        win:Find("PaneBanche").Hidden  = (idx ~= 0)
        win:Find("PaneMemorie").Hidden = (idx ~= 1)
        if idx == 1 then refreshMemoryList() end
    end

    win.On.BtnMemSave.Clicked = function(ev)
        local rawName = win:Find("MemoryName").Text or ""
        local name = rawName:match("^%s*(.-)%s*$")
        if name == "" then
            win:Find("LblMemStatus").Text = "⚠ Inserisci un nome per la configurazione."
            return
        end
        name = name:gsub('[/\\:*?"<>|]', "_")
        local ok, err = saveMemoryFile(name, db)
        if ok then
            win:Find("LblMemStatus").Text = "✓ Configurazione \"" .. name .. "\" salvata  (" .. #db .. " banche)."
            win:Find("MemoryName").Text = ""
            refreshMemoryList()
        else
            win:Find("LblMemStatus").Text = "⚠ Errore: " .. (err or "")
        end
    end

    win.On.BtnMemLoad.Clicked = function(ev)
        local sel = win:Find("MemoryList"):CurrentItem()
        if not sel then
            win:Find("LblMemStatus").Text = "⚠ Seleziona una configurazione dalla lista."
            return
        end
        local name = sel.Text[0]

        local confirmed = false
        local dlg = disp:AddWindow({
            ID = "MemConfirmDlg",
            WindowTitle = "Carica configurazione",
            Geometry = { 280, 280, 440, 145 },
            ui:VGroup{
                ui:Label{ Text = "Caricando  \"" .. name .. "\"\nl'attuale configurazione verrà persa.\n\nProcedere?",
                    Alignment = { AlignHCenter = true } },
                ui:HGroup{
                    ui:HGap{},
                    ui:Button{ ID="BtnMemCfmYes", Text="Carica",  MinimumSize={130,30} },
                    ui:Button{ ID="BtnMemCfmNo",  Text="Annulla", MinimumSize={100,30} },
                    ui:HGap{},
                },
            },
        })
        dlg.On.BtnMemCfmYes.Clicked = function() confirmed = true;  disp:ExitLoop() end
        dlg.On.BtnMemCfmNo.Clicked  = function() disp:ExitLoop() end
        dlg.On.MemConfirmDlg.Close  = function() disp:ExitLoop() end
        dlg:Show(); disp:RunLoop(); dlg:Hide()

        if not confirmed then return end

        savePreviousBackup()

        local dir = getMemoriesDir()
        local sep = package.config:sub(1,1)
        local path = dir .. sep .. name .. ".json"
        local newData, loadErr = loadMemoryFile(path)
        if not newData then
            win:Find("LblMemStatus").Text = "⚠ Errore caricamento: " .. (loadErr or "")
            return
        end

        for i = #db, 1, -1 do table.remove(db, i) end
        for _, e in ipairs(newData) do table.insert(db, e) end
        saveDB(db)
        refreshTree()
        clearForm()
        win:Find("LblMemStatus").Text = "✓ Configurazione \"" .. name .. "\" caricata  (" .. #db .. " banche)."
        refreshMemoryList()
    end

    win.On.BtnMemDelete.Clicked = function(ev)
        local sel = win:Find("MemoryList"):CurrentItem()
        if not sel then
            win:Find("LblMemStatus").Text = "⚠ Seleziona una configurazione dalla lista."
            return
        end
        local name = sel.Text[0]
        local dir = getMemoriesDir()
        local sep = package.config:sub(1,1)
        os.remove(dir .. sep .. name .. ".json")
        refreshMemoryList()
        win:Find("LblMemStatus").Text = "Eliminata: \"" .. name .. "\""
    end

    win.On.BtnMemPrev.Clicked = function(ev)
        local dir = getMemoriesDir()
        local sep = package.config:sub(1,1)
        local path = dir .. sep .. "_previous.json"
        local newData, loadErr = loadMemoryFile(path)
        if not newData then
            win:Find("LblMemStatus").Text = "⚠ Nessun backup precedente trovato."
            return
        end
        for i = #db, 1, -1 do table.remove(db, i) end
        for _, e in ipairs(newData) do table.insert(db, e) end
        saveDB(db)
        refreshTree()
        clearForm()
        os.remove(path)
        win:Find("LblMemStatus").Text = "✓ Configurazione precedente ripristinata  (" .. #db .. " banche)."
        refreshMemoryList()
    end

    win.On.DBConfig.Close = function(ev) disp:ExitLoop() end

    return win
end

-- ============================================================
-- MAIN
-- ============================================================
local db  = loadDB()
local win = buildWindow(db)
win:Show()
disp:RunLoop()
win:Hide()
