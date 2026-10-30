-- ============================================================
-- RepertoireDB_Calculator.lua
-- Calcolatore costi materiale di repertorio per DaVinci Resolve
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

local SCRIPT_VERSION = "1.3.0"

-- LogManager per logging centralizzato
local LogManager = require("LogManager")
LogManager:init()

-- BugReportDialog per segnalazioni bug con privacy notice
local BugReportDialog = require("BugReportDialog")

-- Settings: valuta scelta dall'utente (solo il simbolo, nessuna conversione)
local Settings = require("Settings")
-- Letta all'avvio dello script: cambiando valuta nel Config, le finestre
-- già aperte vanno riaperte per vedere il simbolo nuovo.
local CUR = Settings.cur()

-- Apre un URL nel browser predefinito (cross-platform)
local function openURL(url)
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('start "" "' .. url .. '"')
    else
        os.execute('open "' .. url .. '"')
    end
end

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

-- Apre client mail con oggetto pre-compilato e simultaneamente apre PayPal
local function reportBug(scriptName, version)
    LogManager:info("Calculator.lua", "Segnalazione bug aperta - " .. scriptName .. " v" .. version)

    -- Mostra privacy notice e template
    BugReportDialog:show(scriptName, version)

    -- Tenta di aprire il client email
    local ok = pcall(function()
        BugReportDialog:sendEmail(scriptName, version)
    end)

    if ok then
        LogManager:info("Calculator.lua", "Bug report - client email aperto")
    else
        LogManager:warn("Calculator.lua", "Bug report - errore apertura client email")
    end

    -- Apri PayPal
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        os.execute('start "" "https://paypal.me/acoffeefortom"')
    else
        os.execute('open "https://paypal.me/acoffeefortom"')
    end
end

local json = require("dkjson")

-- ============================================================
-- PERCORSO CONFIG
-- ============================================================
-- FIX v1.2.6: usa uname -s per rilevare macOS (io.open su directory inaffidabile in Resolve 20/21 su Sonoma)
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

local function getReadmePath()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\RepertoireDB_README.txt"
    end
    local home = os.getenv("HOME") or "."
    local h = io.popen("uname -s 2>/dev/null")
    local osname = h and h:read("*a") or ""
    if h then h:close() end
    if osname:match("Darwin") then
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/RepertoireDB_README.txt"
    else
        return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/RepertoireDB_README.txt"
    end
end

local function getScriptDir()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\"
    end
    local home = os.getenv("HOME") or "."
    local h = io.popen("uname -s 2>/dev/null")
    local osname = h and h:read("*a") or ""
    if h then h:close() end
    if osname:match("Darwin") then
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/"
    else
        return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/"
    end
end

-- loadDB() → table
-- Carica il database JSON delle banche dati dal percorso di configurazione.
local function loadDB()
    local path = getConfigPath()
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*all")
    f:close()
    local data, _, err = json.decode(content)
    if err then return {} end
    return data or {}
end

-- buildDbMap(db) → table
-- Costruisce la mappa nome-banca → entry per lookup rapido durante la scansione.
local function dbByName(db)
    local t = {}
    for _, e in ipairs(db) do t[e.name] = e end
    return t
end

-- ============================================================
-- CONVERSIONE TC
-- ============================================================

-- tcToFrames(tcStr, fps) → number
-- Converte timecode HH:MM:SS:FF in numero di frame assoluto.
local function tcToFrames(tcStr, fps)
    fps = tonumber(fps) or 25
    local hh, mm, ss, ff = tcStr:match("(%d+):(%d+):(%d+):(%d+)")
    if not hh then return 0 end
    local fpsInt = math.floor(fps + 0.5)
    return ((tonumber(hh)*3600 + tonumber(mm)*60 + tonumber(ss)) * fpsInt) + tonumber(ff)
end

local function framesToTC(absFrames, fps)
    fps = tonumber(fps) or 25
    absFrames = math.abs(math.floor(absFrames + 0.5))
    local fpsInt = math.floor(fps + 0.5)
    local ff = absFrames % fpsInt
    local totalSec = math.floor(absFrames / fpsInt)
    local ss = totalSec % 60
    local totalMin = math.floor(totalSec / 60)
    local mm = totalMin % 60
    local hh = math.floor(totalMin / 60)
    return string.format("%02d:%02d:%02d:%02d", hh, mm, ss, ff)
end

-- framesToDur(frames, fps) → string
-- Converte frame in stringa durata nel formato MM:SS:FF (non TC assoluto).
local function framesToDur(frames, fps)
    fps = tonumber(fps) or 25
    frames = math.abs(math.floor(frames + 0.5))
    local fpsInt = math.floor(fps + 0.5)
    local ff = frames % fpsInt
    local totalSec = math.floor(frames / fpsInt)
    local ss = totalSec % 60
    local mm = math.floor(totalSec / 60)
    return string.format("%02d:%02d:%02d", mm, ss, ff)
end

-- ============================================================
-- DURATA SORGENTE v1.1
-- Usa GetSourceStartFrame/GetSourceEndFrame (API nativa Resolve)
-- Gestisce correttamente: normale, slow motion, reverse, freeze frame
-- ============================================================
local function getSourceFrames(clip)
    local inF  = clip:GetSourceStartFrame()
    local outF = clip:GetSourceEndFrame()
    -- Reverse: frame sorgente invertiti (Start > End)
    if inF and outF and inF > outF then
        inF, outF = outF, inF
    end
    -- Freeze frame: Start == End (un solo frame sorgente ripetuto in TL)
    if inF and outF and inF == outF then
        local tlDur = clip:GetDuration()
        if tlDur and tlDur > 1 then
            outF = inF + 1
        end
    end
    if not inF or not outF then return nil, nil end
    return inF, outF
end

-- Restituisce Src In e Src Out come TC assoluto del file sorgente (solo display/CSV)
-- Usa Start TC del media item + GetSourceStartFrame/EndFrame per il calcolo corretto
local function getSourceTC(clip, mediaItem, fps)
    fps = tonumber(fps) or 25

    -- TC assoluto di inizio del file sorgente
    local startTCStr = mediaItem:GetClipProperty("Start TC")
    if not startTCStr or startTCStr == "" then
        return "??:??:??:??", "??:??:??:??"
    end
    local startTCFrames = tcToFrames(startTCStr, fps)

    -- Frame sorgente relativi al segmento (già corretti per reverse e freeze)
    local inF, outF = getSourceFrames(clip)
    if not inF then
        return "??:??:??:??", "??:??:??:??"
    end

    -- TC assoluto = TC start file + frame relativi del segmento
    local absIn  = startTCFrames + inF
    local absOut = startTCFrames + outF

    return framesToTC(absIn, fps), framesToTC(absOut, fps)
end

-- ============================================================
-- DURATA SORGENTE IN SECONDI E FRAME  v1.1
-- ============================================================
local function getSourceDuration(clip, fps)
    fps = tonumber(fps) or 25
    local tlFrames = math.abs(clip:GetEnd() - clip:GetStart())
    local tlSec    = tlFrames / fps
    local inF, outF = getSourceFrames(clip)
    if inF and outF then
        local srcFrames = outF - inF
        if srcFrames > 0 then
            return srcFrames / fps, srcFrames, tlSec
        end
    end
    -- Fallback: nessun dato sorgente, usa durata timeline
    return tlSec, tlFrames, tlSec
end

-- ============================================================
-- CALCOLO COSTO BASE (senza sconti)
-- ============================================================
local function calcCostBase(entry, sourceSec)
    local model = entry.model
    local rate  = entry.rate
    if not rate then return nil, "da definire" end
    if model == "A clip" then
        return rate, "1 utilizzo"
    elseif model == "Al secondo" then
        local secs = math.ceil(sourceSec)
        return secs * rate, secs .. "s sorg"
    elseif model == "A blocchi (custom)" then
        local blockSec = entry.blockSec or 30
        local blocks   = math.ceil(sourceSec / blockSec)
        return blocks * rate, blocks .. "bl×" .. blockSec .. "s"
    elseif model == "Al minuto" then
        local mins = math.ceil(sourceSec / 60.0)
        return mins * rate, mins .. "min"
    elseif model == "Forfait" then
        return rate, "forfait"
    end
    return 0, "?"
end

-- ============================================================
-- COSTO PROPORZIONALE (nessun arrotondamento, display per-clip)
-- ============================================================
-- Restituisce il costo come quota lineare della durata, senza ceil.
-- Usato per i valori display delle singole clip/segmenti.
-- Il fatturato effettivo viene calcolato con calcCostBase sul totale banca.
local function calcCostProportional(entry, sourceSec)
    local model = entry.model
    local rate  = entry.rate
    if not rate then return nil end
    if model == "A clip" then
        return rate                              -- flat, non cambia
    elseif model == "Al secondo" then
        return sourceSec * rate                  -- già per-secondo, lineare
    elseif model == "A blocchi (custom)" then
        local blockSec = entry.blockSec or 30
        return sourceSec * rate / blockSec       -- quota lineare del blocco
    elseif model == "Al minuto" then
        return sourceSec * rate / 60.0           -- quota lineare del minuto
    elseif model == "Forfait" then
        return 0                                 -- costo fisso sul totale banca, non per-clip
    end
    return 0
end

-- ============================================================
-- LABEL ARROTONDAMENTO (per nota discrepanza sul totale banca)
-- ============================================================
local function roundedToLabel(entry, totalSec)
    local model = entry.model
    if model == "Al secondo" then
        local u = math.ceil(totalSec)
        return string.format("ARROTONDATO A %d second%s", u, u == 1 and "o" or "i")
    elseif model == "Al minuto" then
        local u = math.ceil(totalSec / 60)
        return string.format("ARROTONDATO A %d minut%s", u, u == 1 and "o" or "i")
    elseif model == "A blocchi (custom)" then
        local blockSec = entry.blockSec or 30
        local u = math.ceil(totalSec / blockSec)
        return string.format("ARROTONDATO A %d blocc%s da %ds",
            u, u == 1 and "o" or "hi", blockSec)
    end
    return nil
end

-- ============================================================
-- APPLICA SCONTI
-- ============================================================
-- totalSec: durata totale in secondi per la banca dati
-- costBase: costo calcolato prima degli sconti
-- discounts: array di {threshold_sec, pct, type}
-- Ritorna: costoFinale, descrizioneSconto

-- clipCount: numero di clip uniche nella banca (usato solo per modello "A clip")
local function applyDiscounts(entry, totalSec, costBase, clipCount)
    if not entry.rate then return nil, nil end
    local discounts = entry.discounts
    if not discounts or #discounts == 0 then
        return costBase, nil
    end

    local isClipModel = (entry.model == "A clip")

    -- Trova la soglia più alta superata
    -- Per "A clip": confronta clipCount con threshold_clips
    -- Per gli altri modelli: confronta totalSec con threshold_sec
    local appliedDiscount = nil
    for _, d in ipairs(discounts) do
        if isClipModel then
            if d.threshold_clips and (clipCount or 0) > d.threshold_clips then
                appliedDiscount = d
            end
        else
            if d.threshold_sec and totalSec > d.threshold_sec then
                appliedDiscount = d
            end
        end
    end

    if not appliedDiscount then
        return costBase, nil
    end

    -- Etichetta soglia per le note
    local threshLabel
    if isClipModel and appliedDiscount.threshold_clips then
        threshLabel = appliedDiscount.threshold_clips .. " clip"
    else
        threshLabel = tostring(appliedDiscount.threshold_sec) .. "s"
    end

    local finalCost, discNote

    if appliedDiscount.type == "flat" or isClipModel then
        -- Flat: percentuale sull'intero importo
        -- Per "A clip" si usa sempre flat (non ha senso il progressivo su clip discrete)
        local discAmount = costBase * appliedDiscount.pct / 100
        finalCost = costBase - discAmount
        discNote  = string.format("Sconto flat %d%% (oltre %s) = -%s",
            appliedDiscount.pct, threshLabel, Settings.money(discAmount))

    else
        -- Progressivo: tariffa ridotta solo sulla parte eccedente la soglia
        local model         = entry.model
        local rate          = entry.rate
        local discRate      = rate * (1 - appliedDiscount.pct / 100)
        local threshold_sec = appliedDiscount.threshold_sec

        if model == "Al secondo" then
            local secsBase = math.min(math.ceil(totalSec), math.ceil(threshold_sec))
            local secsDisc = math.max(0, math.ceil(totalSec) - math.ceil(threshold_sec))
            finalCost = secsBase * rate + secsDisc * discRate
            discNote  = string.format("Sconto prog %d%% su %ds eccedenti (oltre %s) = -%s",
                appliedDiscount.pct, secsDisc, threshLabel, Settings.money(costBase - finalCost))

        elseif model == "Al minuto" then
            local minsTotal = math.ceil(totalSec / 60)
            local minsBase  = math.min(minsTotal, math.ceil(threshold_sec / 60))
            local minsDisc  = math.max(0, minsTotal - minsBase)
            finalCost = minsBase * rate + minsDisc * discRate
            discNote  = string.format("Sconto prog %d%% su %dmin eccedenti (oltre %s) = -%s",
                appliedDiscount.pct, minsDisc, threshLabel, Settings.money(costBase - finalCost))

        elseif model == "A blocchi (custom)" then
            local blockSec    = entry.blockSec or 30
            local blocksTotal = math.ceil(totalSec / blockSec)
            local blocksBase  = math.min(blocksTotal, math.ceil(threshold_sec / blockSec))
            local blocksDisc  = math.max(0, blocksTotal - blocksBase)
            finalCost = blocksBase * rate + blocksDisc * discRate
            discNote  = string.format("Sconto prog %d%% su %d blocchi eccedenti (oltre %s) = -%s",
                appliedDiscount.pct, blocksDisc, threshLabel, Settings.money(costBase - finalCost))

        else
            local discAmount = costBase * appliedDiscount.pct / 100
            finalCost = costBase - discAmount
            discNote  = string.format("Sconto %d%% (oltre %s) = -%s",
                appliedDiscount.pct, threshLabel, Settings.money(discAmount))
        end
    end

    return finalCost, discNote
end

-- ============================================================
-- SCANSIONE TIMELINE
-- ============================================================
local METADATA_FIELD = "Keywords"

-- scanTimeline(timeline, dbMap, fps) → results, unknownClips
-- Scansiona la timeline e classifica i clip per banca dati tramite metadato Keywords.
local function scanTimeline(timeline, dbMap, fps)
    local results      = {}
    local unknownClips = {}
    local trackCount   = timeline:GetTrackCount("video")

    LogManager:debug("Calculator.lua", "Scansione timeline - " .. trackCount .. " tracce video rilevate")

    for trackIdx = 1, trackCount do
        local clips = timeline:GetItemListInTrack("video", trackIdx)
        if clips then
            for _, clip in ipairs(clips) do
                local ok, err = pcall(function()
                    local mediaItem = clip:GetMediaPoolItem()
                    if not mediaItem then return end

                    local kwRaw = mediaItem:GetMetadata(METADATA_FIELD)
                    if not kwRaw or kwRaw == "" then return end

                    -- Cerca il primo nome di archivio tra le keyword (supporta più keyword separate da ; , \n)
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

                    local ok_uid, uid = pcall(function() return mediaItem:GetUniqueId() end)
                    local key = (ok_uid and uid and uid ~= "" and uid or tostring(mediaItem)) .. "|" .. dbName

                    -- Nome clip
                    local mediaName = "Unknown"
                    local ok2, nv = pcall(function()
                        return mediaItem:GetClipProperty("Clip Name")
                            or mediaItem:GetClipProperty("File Name")
                            or clip:GetName()
                            or "Unknown"
                    end)
                    if ok2 and nv and nv ~= "" then mediaName = nv end

                    if not results[key] then
                        local clipFileName = mediaItem:GetClipProperty("File Name") or clip:GetName() or "Unknown"
                        results[key] = {
                            name      = clipFileName,
                            dbEntry   = entry,
                            dbName    = dbName,
                            mediaName = mediaName,
                            segments  = {},
                        }
                    end

                    local sourceSec, srcFramesDirect, timelineSec = getSourceDuration(clip, fps)
                    local tlIn,  tlOut  = framesToTC(clip:GetStart(), fps), framesToTC(clip:GetEnd(), fps)
                    local srcIn, srcOut = getSourceTC(clip, mediaItem, fps)
                    local srcInFrames, srcOutFrames = getSourceFrames(clip)
                    srcInFrames  = srcInFrames  or 0
                    srcOutFrames = srcOutFrames or 0

                    -- ── Rilevamento retime v1.1 ──────────────────────────────
                    local retimeType = nil
                    local tlFrames   = math.abs(clip:GetEnd() - clip:GetStart())
                    local rawIn      = clip:GetSourceStartFrame()
                    local rawOut     = clip:GetSourceEndFrame()
                    if rawIn and rawOut and rawIn == rawOut then
                        -- Freeze frame: stessa posizione sorgente per in e out
                        if tlFrames > 1 then retimeType = "Freeze Frame" end
                    elseif rawIn and rawOut and rawIn > rawOut then
                        -- Reverse: frame invertiti
                        local srcSec = (rawIn - rawOut) / fps
                        if timelineSec > 0.001 then
                            local ratio = srcSec / timelineSec
                            if ratio > 1.1 then
                                retimeType = string.format("Reverse + Time Warp %d%%",
                                    math.floor(ratio * 100 + 0.5))
                            elseif ratio < 0.9 then
                                retimeType = string.format("Reverse + Slow Motion %d%%",
                                    math.floor(ratio * 100 + 0.5))
                            else
                                retimeType = "Reverse"
                            end
                        else
                            retimeType = "Reverse"
                        end
                    elseif timelineSec > 0.001 and srcFramesDirect > 0 then
                        -- Retime normale (no reverse)
                        local ratio = sourceSec / timelineSec
                        if ratio > 1.1 then
                            retimeType = string.format("Time Warp %d%%",
                                math.floor(ratio * 100 + 0.5))
                        elseif ratio < 0.9 then
                            retimeType = string.format("Slow Motion %d%%",
                                math.floor(ratio * 100 + 0.5))
                        end
                    end

                    table.insert(results[key].segments, {
                        sourceSec    = sourceSec,
                        sourceFrames = srcFramesDirect,
                        srcFps       = fps,
                        timelineSec  = timelineSec,
                        srcIn        = srcIn,
                        srcOut       = srcOut,
                        srcInFrames  = srcInFrames,
                        srcOutFrames = srcOutFrames,
                        tlIn         = tlIn,
                        tlOut        = tlOut,
                        retimeType   = retimeType,
                    })
                end)
                if not ok then
                    LogManager:error("Calculator.lua", "Errore durante scansione clip: " .. tostring(err))
                end
            end
        end
    end
    return results, unknownClips
end

-- ============================================================
-- HELPERS DEDUPLICAZIONE INTERVALLI FRAME SORGENTE
-- ============================================================

-- Quanti frame in [inF, outF) NON sono già coperti da `covered`?
-- `covered` è una lista di {inF, outF} non sovrapposti e ordinati.
local function uniqueFramesIn(inF, outF, covered)
    local overlap = 0
    for _, iv in ipairs(covered) do
        local lo = math.max(inF, iv[1])
        local hi = math.min(outF, iv[2])
        if hi > lo then overlap = overlap + (hi - lo) end
    end
    return math.max(0, (outF - inF) - overlap)
end

-- Aggiunge [inF, outF) a `covered`, mantenendolo ordinato e non sovrapposto.
-- Restituisce la nuova lista.
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
-- SCANSIONE TRACCE AUDIO
-- ============================================================
-- Solo banche Video, esclusi modelli "A clip".
-- Restituisce audioGroups[uid|dbName] → { dbName, covered, dbEntry }
local function scanAudio(timeline, dbMap, fps)
    local audioGroups = {}
    local trackCount  = timeline:GetTrackCount("audio")
    for trackIdx = 1, trackCount do
        local clips = timeline:GetItemListInTrack("audio", trackIdx)
        if clips then
            for _, clip in ipairs(clips) do
                pcall(function()
                    local mi = clip:GetMediaPoolItem()
                    if not mi then return end
                    local dbName = mi:GetMetadata(METADATA_FIELD)
                    if not dbName or dbName == "" then return end
                    dbName = dbName:match("^%s*(.-)%s*$")
                    local entry = dbMap[dbName]
                    if not entry then return end
                    if (entry.mediaType or "Video") ~= "Video" then return end
                    if entry.model == "A clip" or entry.model == "Forfait" then return end
                    local ok_uid, uid = pcall(function() return mi:GetUniqueId() end)
                    local uidVal = (ok_uid and uid and uid ~= "" and uid or tostring(mi))
                    local key = uidVal .. "|" .. dbName
                    if not audioGroups[key] then
                        audioGroups[key] = { dbName=dbName, covered={}, dbEntry=entry }
                    end
                    local inF, outF = getSourceFrames(clip)
                    if not inF then return end
                    audioGroups[key].covered = addInterval(audioGroups[key].covered, inF, outF)
                end)
            end
        end
    end
    return audioGroups
end

-- ============================================================
-- CALCOLO AUDIO ECCEDENTE IL VIDEO (spazio sorgente)
-- ============================================================
-- Per ogni sorgente taggata: frame audio NON coperti dal video
-- dello stesso file → "eccedenti". Questo cattura sia il caso
-- "audio più lungo del video" (testa/coda) sia "solo audio".
-- Costo = modello normale × 0.5, nessuno sconto.
-- Restituisce excessByDB[dbName] → { frames, cost, durStr, dbEntry }
-- e audioTotal (number).

-- calcExcessAudio(videoResults, audioGroups, fps) → excessByDB, audioTotal
-- Calcola l'audio eccedente per ogni banca dati (frame audio non coperti dal video).
local function calcExcessAudio(videoResults, audioGroups, fps)
    -- Ricostruisce gli intervalli video per ogni uid|dbName
    local videoCovered = {}
    for key, data in pairs(videoResults) do
        for _, seg in ipairs(data.segments) do
            local inF  = seg.srcInFrames  or 0
            local outF = seg.srcOutFrames or 0
            if outF > inF then
                if not videoCovered[key] then videoCovered[key] = {} end
                videoCovered[key] = addInterval(videoCovered[key], inF, outF)
            end
        end
    end

    -- Per ogni clip audio, sottrae i frame già coperti dal video
    -- Solo per le banche con audioExcess = true
    local excessByDB = {}
    for key, ag in pairs(audioGroups) do
        if not (ag.dbEntry and ag.dbEntry.audioExcess) then goto continue_audio end
        local vidIntervals = videoCovered[key] or {}
        local exFr = 0
        for _, iv in ipairs(ag.covered) do
            local overlap = 0
            for _, vi in ipairs(vidIntervals) do
                local lo = math.max(iv[1], vi[1])
                local hi = math.min(iv[2], vi[2])
                if hi > lo then overlap = overlap + (hi - lo) end
            end
            exFr = exFr + math.max(0, (iv[2] - iv[1]) - overlap)
        end
        if exFr > 0 then
            local dbName = ag.dbName
            if not excessByDB[dbName] then
                excessByDB[dbName] = { frames=0, dbEntry=ag.dbEntry }
            end
            excessByDB[dbName].frames = excessByDB[dbName].frames + exFr
        end
        ::continue_audio::
    end

    -- Calcola costo: 50% tariffa piena, nessuno sconto, arrotondamento standard
    local audioTotal = 0
    for _, ex in pairs(excessByDB) do
        local entry = ex.dbEntry
        local exSec = ex.frames / fps
        ex.durStr   = framesToDur(ex.frames, fps)
        if not entry.rate then
            ex.cost = nil   -- tariffa non ancora definita
        else
            local costFull = 0
            if entry.model == "Al secondo" then
                costFull = math.ceil(exSec) * entry.rate
            elseif entry.model == "Al minuto" then
                costFull = math.ceil(exSec / 60) * entry.rate
            elseif entry.model == "A blocchi (custom)" then
                local bs = entry.blockSec or 30
                costFull = math.ceil(exSec / bs) * entry.rate
            end
            ex.cost    = costFull * 0.5
            audioTotal = audioTotal + ex.cost
        end
    end

    return excessByDB, audioTotal
end

-- ============================================================
-- AGGREGAZIONE COSTI
-- ============================================================
-- Logica di calcolo:
--   • Per-segmento  : calcCostBase(entry, seg.uniqueSec)          — display informativo
--   • Per-clip      : calcCostBase(entry, clip.totalUniqueSec)    — display informativo
--   • Per-banca     : calcCostBase(entry, sum_durate_banca)       — FATTURATO EFFETTIVO
--     (un unico ceil sull'intera durata aggregata, non somma di ceil per clip)
--   Se la somma dei costi per-clip ≠ costo-banca: discrepanza da arrotondamento

-- aggregateCosts(results, fps) → rows, byDB, byDur, dbFinalCost, dbDiscountNote, dbTotalSec, grandTotal, grandFrames, dbCostBase, dbRoundNote, dbEntryByName, undefinedBanks
-- Aggrega i costi per banca dati, applica sconti e arrotondamenti sul totale aggregato.
local function aggregateCosts(results, fps)
    local rows           = {}
    local byDB           = {}   -- somma costi per-clip (display, NON il fatturato)
    local byDur          = {}
    local grandFrames    = 0
    local dbEntryByName  = {}   -- dbEntry di riferimento per banca
    local undefinedBanks = {}   -- banche senza tariffa definita

    -- ── Prima passata: dedup + costo display per clip ────────────────
    for _, data in pairs(results) do
        local entry       = data.dbEntry
        local model       = entry.model
        local srcFpsGroup = (data.segments[1] and data.segments[1].srcFps) or fps

        -- Deduplicazione frame sorgente
        local covered       = {}
        local hasDups       = false
        local totalUniqueFr = 0

        for _, seg in ipairs(data.segments) do
            local inF  = seg.srcInFrames  or 0
            local outF = seg.srcOutFrames or 0

            local segTotal  = outF - inF
            local segUnique = uniqueFramesIn(inF, outF, covered)
            covered         = addInterval(covered, inF, outF)

            seg.uniqueFrames = segUnique
            seg.totalFrames  = segTotal
            seg.uniqueSec    = segUnique / (seg.srcFps or fps)

            if segTotal == 0 or segUnique == segTotal then
                seg.dupStatus = "nuovo"
            elseif segUnique == 0 then
                seg.dupStatus = "duplicato"
                hasDups = true
            else
                seg.dupStatus = "parziale"
                hasDups = true
            end
            totalUniqueFr = totalUniqueFr + segUnique
        end

        local totalUniqueSec = totalUniqueFr / srcFpsGroup
        if data.transitionDurationSec then
            totalUniqueSec = totalUniqueSec + data.transitionDurationSec
        end

        if hasDups then
            LogManager:debug("Calculator.lua", "Deduplicazione frame - " .. data.mediaName .. ": duplicati trovati | Totale frame unici: " .. totalUniqueFr)
        end

        -- Costo display per clip (proporzionale, senza ceil)
        local clipCost = 0
        local detail   = ""

        if model == "A clip" then
            clipCost = entry.rate   -- nil se tariffa non definita
            detail   = "1 utilizzo (flat)"
        elseif model == "Forfait" then
            clipCost = 0
            detail   = "compreso nel forfait"
        else
            -- Costo proporzionale: nessun ceil, valore lineare sulla durata unica.
            -- La fatturazione con arrotondamento avviene sul totale banca (dbCostBase).
            clipCost = calcCostProportional(entry, totalUniqueSec)

            local segDetails = {}
            for _, seg in ipairs(data.segments) do
                local durStr = framesToDur(seg.sourceFrames or 0, seg.srcFps or fps)
                local rtPfx  = seg.retimeType and ("[" .. seg.retimeType .. "] ") or ""
                if seg.dupStatus == "duplicato" then
                    table.insert(segDetails, rtPfx .. durStr .. "=⚠RIPETUTO")
                elseif seg.dupStatus == "parziale" then
                    local uDur = framesToDur(seg.uniqueFrames, seg.srcFps or fps)
                    table.insert(segDetails, rtPfx .. durStr .. "(+" .. uDur .. "unici)")
                else
                    table.insert(segDetails, rtPfx .. durStr)
                end
            end
            detail = table.concat(segDetails, " | ")
                  .. (clipCost and ("  →" .. Settings.money(clipCost)) or "  →DA DEFINIRE")
        end

        if clipCost == nil then undefinedBanks[data.dbName] = true end

        grandFrames = grandFrames + totalUniqueFr

        if not byDB[data.dbName]  then byDB[data.dbName]  = 0 end
        if not byDur[data.dbName] then byDur[data.dbName] = 0 end
        if clipCost then byDB[data.dbName] = byDB[data.dbName] + clipCost end
        byDur[data.dbName] = byDur[data.dbName] + totalUniqueFr
        dbEntryByName[data.dbName] = entry

        table.insert(rows, {
            mediaName           = data.mediaName,
            dbName              = data.dbName,
            mediaType           = entry.mediaType or "Video",
            model               = model,
            cost                = clipCost,      -- display per-clip (può differire dal fatturato banca)
            detail              = detail,
            segmentCount        = #data.segments,
            segments            = data.segments,
            dbEntry             = entry,
            totalSourceSec      = totalUniqueSec,
            hasDuplicates       = hasDups,
            transitionInfo      = data.transitionInfo,
            transitionDurationSec = data.transitionDurationSec,
        })
    end

    -- ── Calcolo secondi inutilizzati per arrotondamento ─────────────
    -- Eseguito prima della seconda passata per poter usare dbCostBase.
    -- Il badge viene calcolato dopo la seconda passata (vedi sotto).

    -- ── Seconda passata: costo banca aggregato (fatturato effettivo) ─
    -- Somma prima le durate, poi applica UN SOLO ceil.
    -- Questo elimina le discrepanze da doppio-ceil (30s+30s = 1min, non 2min).
    local dbTotalSec    = {}
    local dbCostBase    = {}   -- fatturato base per banca (prima dei sconti)
    local dbRoundNote   = {}   -- nota discrepanza se byDB ≠ dbCostBase

    for _, row in ipairs(rows) do
        if not dbTotalSec[row.dbName] then dbTotalSec[row.dbName] = 0 end
        dbTotalSec[row.dbName] = dbTotalSec[row.dbName] + row.totalSourceSec
    end

    -- Tabella secondi scoperti (utilizzo minimo non raggiunto)
    local dbUncoveredSec = {}

    for dbName, totalSec in pairs(dbTotalSec) do
        local entry = dbEntryByName[dbName]
        -- Utilizzo Minimo: per modelli temporali fattura almeno utilMin secondi
        local isTimeBased = entry.model ~= "A clip" and entry.model ~= "Forfait"
        local effectiveSec = (isTimeBased and entry.utilMin and entry.utilMin > 0)
            and math.max(totalSec, entry.utilMin) or totalSec

        -- Calcola secondi scoperti se utilizzo < minimo
        if isTimeBased and entry.utilMin and entry.utilMin > 0 and totalSec < entry.utilMin then
            dbUncoveredSec[dbName] = entry.utilMin - totalSec
        end

        if not entry.rate then
            dbCostBase[dbName] = nil
            undefinedBanks[dbName] = true
        elseif entry.model == "A clip" then
            -- Flat: nessun arrotondamento, somma diretta
            dbCostBase[dbName] = byDB[dbName]
        elseif entry.model == "Forfait" then
            -- Prezzo fisso indipendente da durata e numero clip
            dbCostBase[dbName] = entry.rate
        else
            dbCostBase[dbName], _ = calcCostBase(entry, effectiveSec)
        end
        if dbCostBase[dbName] and entry.model ~= "Forfait" then
            local displaySum = byDB[dbName] or 0
            if math.abs(displaySum - dbCostBase[dbName]) > 0.005 then
                local rlabel = roundedToLabel(dbEntryByName[dbName], effectiveSec) or "ARROTONDATO"
                dbRoundNote[dbName] = string.format(
                    "%s  (proporzionale %s → fatturato %s)",
                    rlabel, Settings.money(displaySum), Settings.money(dbCostBase[dbName]))
            end
        end
    end

    -- Conteggio clip uniche per banca (usato da applyDiscounts per modello "A clip")
    local clipCountByBank = {}
    for _, row in ipairs(rows) do
        clipCountByBank[row.dbName] = (clipCountByBank[row.dbName] or 0) + 1
    end

    -- Sconti applicati su dbCostBase (non su byDB)
    local dbDiscountNote = {}
    local dbFinalCost    = {}
    local grandTotal     = 0

    for _, row in ipairs(rows) do
        if dbFinalCost[row.dbName] == nil and not undefinedBanks[row.dbName] then
            local finalCost, discNote = applyDiscounts(
                row.dbEntry, dbTotalSec[row.dbName], dbCostBase[row.dbName],
                clipCountByBank[row.dbName])
            dbFinalCost[row.dbName]    = finalCost
            dbDiscountNote[row.dbName] = discNote
        end
    end

    for _, finalCost in pairs(dbFinalCost) do
        if finalCost then grandTotal = grandTotal + finalCost end
    end

    return rows, byDB, byDur, dbFinalCost, dbDiscountNote, dbTotalSec,
           grandTotal, grandFrames, dbCostBase, dbRoundNote, dbEntryByName, undefinedBanks, dbUncoveredSec
end

-- ============================================================
-- EXPORT CSV
-- ============================================================

-- generateCSVReport(...) → path, error
-- Genera il report CSV da esportare: chiede la cartella di destinazione e scrive il file completo.
local function exportCSV(rows, byDB, byDur, dbFinalCost, dbDiscountNote, grandTotal, grandFrames, timelineName, fps, dbCostBase, dbRoundNote, dbEntryByName, excessByDB, audioTotal, undefinedBanks, sortByBank, dbUncoveredSec)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename  = "RepertoireDB_" .. timelineName:gsub("[^%w]", "_") .. "_" .. timestamp .. ".csv"

    local home    = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
    local desktop = home .. "/Desktop"
    local dir = fu:RequestDir(desktop)
    if not dir or dir == "" then return nil, "Esportazione annullata" end
    if not dir:match("[/\\]$") then dir = dir .. "/" end
    local path = dir .. filename

    local f = io.open(path, "w")
    if not f then return nil, "Impossibile scrivere in: " .. dir end

    audioTotal = audioTotal or 0

    -- BOM UTF-8 + intestazione
    f:write("\xEF\xBB\xBF")
    f:write("⚠ CALCOLO APPROSSIMATIVO — questo report non sostituisce il calcolo ufficiale della produzione. I costi sono indicativi e soggetti a variazioni contrattuali.\n")
    f:write(SCRIPT_VERSION .. "\n")
    f:write("Timeline: " .. timelineName .. "\n")
    f:write("Generato: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")

    -- ── Prepara raggruppamenti (usati in sezioni A/B) ────────────────────────
    local clipCountByDB = {}
    for _, row in ipairs(rows) do
        clipCountByDB[row.dbName] = (clipCountByDB[row.dbName] or 0) + 1
    end

    local cats = { "Video", "Fotografie", "Giornali" }
    local byCategory = { Video={}, Fotografie={}, Giornali={} }
    local dbNames = {}
    for k in pairs(byDB) do table.insert(dbNames, k) end
    table.sort(dbNames)
    for _, name in ipairs(dbNames) do
        local mt = (dbEntryByName and dbEntryByName[name] and dbEntryByName[name].mediaType) or "Video"
        if byCategory[mt] then table.insert(byCategory[mt], name)
        else table.insert(byCategory["Video"], name) end
    end

    -- ── A) SUBTOTALI PER BANCA (raggruppati per categoria) ──────────────────
    for _, cat in ipairs(cats) do
        local names = byCategory[cat]
        if #names > 0 then
            f:write("*** " .. cat:upper() .. " ***\n")
            if cat == "Video" then
                f:write("Banca Dati,Costo Lordo " .. CUR .. ",Somma Clip " .. CUR .. ",Sconto,Costo Netto " .. CUR .. ",Durata totale,Secondi Scoperti,Note\n")
            else
                f:write("Banca Dati,Costo Lordo " .. CUR .. ",N. Clip,Sconto,Costo Netto " .. CUR .. ",Note\n")
            end
            local subtot     = 0
            local subtotDurFr = 0
            local subtotClips = 0
            for _, name in ipairs(names) do
                local net     = dbFinalCost  and dbFinalCost[name]
                local base    = dbCostBase   and dbCostBase[name]
                local discStr = dbDiscountNote and dbDiscountNote[name] or ""
                local rndNote = dbRoundNote  and dbRoundNote[name]  or ""
                local netStr  = net  and string.format("%.2f", net)  or "DA DEFINIRE"
                local baseStr = base and string.format("%.2f", base) or "DA DEFINIRE"
                if net then subtot = subtot + net end
                if cat == "Video" then
                    local durStr = framesToDur(byDur and byDur[name] or 0, fps)
                    subtotDurFr  = subtotDurFr + (byDur and byDur[name] or 0)
                    local entry = dbEntryByName and dbEntryByName[name]
                    local prop  = byDB[name] or 0
                    local unusedNote = rndNote
                    if base and entry and base > prop + 0.005 then
                        local extraCost = base - prop
                        local unusedSec = 0
                        if entry.model == "Al minuto" and entry.rate and entry.rate > 0 then
                            unusedSec = math.floor(extraCost / (entry.rate / 60) + 0.5)
                        elseif entry.model == "A blocchi (custom)" and entry.rate and entry.rate > 0 then
                            local blockSec = entry.blockSec or 30
                            unusedSec = math.floor(extraCost / (entry.rate / blockSec) + 0.5)
                        end
                        if unusedSec > 0 then
                            local badge = string.format("⚠ %d sec inutilizzati → %s extra", unusedSec, Settings.money(extraCost))
                            unusedNote = unusedNote ~= "" and (unusedNote .. "  |  " .. badge) or badge
                        end
                    end
                    local uncoveredStr = (dbUncoveredSec and dbUncoveredSec[name]) or ""
                    f:write(string.format('"%s","%s","%.2f","%s","%s","%s","%s","%s"\n',
                        name, baseStr, byDB[name] or 0, discStr, netStr, durStr, uncoveredStr, unusedNote))
                else
                    local nc = clipCountByDB[name] or 0
                    subtotClips = subtotClips + nc
                    f:write(string.format('"%s","%s","%d","%s","%s","%s"\n',
                        name, baseStr, nc, discStr, netStr, rndNote))
                end
            end
            -- B) Subtotale categoria (bold con ***)
            if cat == "Video" then
                f:write(string.format('"*** SUBTOTALE VIDEO ***","","","","%.2f","%s","",""\n',
                    subtot, framesToDur(subtotDurFr, fps)))
            else
                f:write(string.format('"*** SUBTOTALE %s ***","","","","%.2f","%d clip",""\n',
                    cat:upper(), subtot, subtotClips))
            end
            f:write("\n")
        end
    end

    -- Audio eccedente (come sezione separata nel riepilogo)
    if excessByDB and next(excessByDB) then
        f:write("*** AUDIO ECCEDENTE ***\n")
        f:write("Banca Dati,Durata Eccedente,Costo Audio EUR,Note\n")
        local audioNames = {}
        for k in pairs(excessByDB) do table.insert(audioNames, k) end
        table.sort(audioNames)
        for _, name in ipairs(audioNames) do
            local ex = excessByDB[name]
            f:write(string.format('"%s","%s","%.2f","50%% tariffa piena - no sconti"\n',
                name, ex.durStr or "", ex.cost or 0))
        end
        f:write(string.format('"*** SUBTOTALE AUDIO ECCEDENTE ***","","%.2f",""\n', audioTotal))
        f:write("\n")
    end

    -- ── C) TOTALE GENERALE ──────────────────────────────────────────────────
    f:write(string.format('"*** TOTALE GENERALE ***","","","","%.2f","%s","",""\n',
        grandTotal + audioTotal, framesToDur(grandFrames or 0, fps)))
    f:write("\n")

    -- ── D) BANCHE CON COSTO DA DEFINIRE ─────────────────────────────────────
    if undefinedBanks and next(undefinedBanks) then
        f:write("*** BANCHE CON COSTO DA DEFINIRE (non incluse nel totale) ***\n")
        f:write("Banca Dati,Nota\n")
        local uNames = {}
        for k in pairs(undefinedBanks) do table.insert(uNames, k) end
        table.sort(uNames)
        for _, name in ipairs(uNames) do
            f:write(string.format('"%s","Costo da definire — non incluso nel totale"\n', name))
        end
        f:write("\n")
    end

    -- ── E) DETTAGLIO SEGMENTI ────────────────────────────────────────────────
    local sortLabel = sortByBank and "PER BANCA DATI" or "ORDINE DI MONTAGGIO"
    f:write("*** DETTAGLIO SEGMENTI — " .. sortLabel .. " ***\n")
    f:write("File,Tipo,Banca Dati,Modello,Src In,Src Out,Durata Sorgente,Rec TC In,Rec TC Out,Durata Montato,Costo Segmento " .. CUR .. ",Note\n")

    local sortedRows = {}
    for _, row in ipairs(rows) do table.insert(sortedRows, row) end
    if sortByBank then
        table.sort(sortedRows, function(a, b)
            if a.dbName ~= b.dbName then return a.dbName < b.dbName end
            return (a.mediaName or "") < (b.mediaName or "")
        end)
    end

    local currentBank = nil
    for _, row in ipairs(sortedRows) do
        if sortByBank and row.dbName ~= currentBank then
            currentBank = row.dbName
            f:write(string.format('"--- %s ---","","","","","","","","","","",""\n', currentBank))
        end
        for segIdx, seg in ipairs(row.segments) do
            local segCost = 0
            local note    = ""
            if row.model == "A clip" then
                segCost = (segIdx == 1) and row.cost or 0
                if segIdx > 1 then note = "incluso nel primo utilizzo" end
            elseif row.model == "Forfait" then
                segCost = 0
                note    = "compreso nel forfait"
            else
                local ds = seg.dupStatus or "nuovo"
                if ds == "duplicato" then
                    segCost = 0
                    note    = string.format("⚠ RIPETUTO — %s già conteggiati (src %s→%s)",
                        framesToDur(seg.sourceFrames or 0, seg.srcFps or fps),
                        seg.srcIn or "?", seg.srcOut or "?")
                elseif ds == "parziale" then
                    segCost = 0
                    note    = string.format("⚠ PARZIALMENTE RIPETUTO — %d frame unici su %d (src %s→%s)",
                        seg.uniqueFrames or 0, seg.totalFrames or 0,
                        seg.srcIn or "?", seg.srcOut or "?")
                else
                    segCost = calcCostProportional(row.dbEntry, seg.uniqueSec or seg.sourceSec or 0)
                end
                if seg.retimeType then
                    note = (note ~= "" and (note .. "  |  ") or "") .. seg.retimeType
                end
            end
            local durSrc    = framesToDur(seg.sourceFrames or 0, seg.srcFps or fps)
            local durMontato = framesToDur(math.floor((seg.timelineSec or seg.sourceSec or 0) * fps + 0.5), fps)
            local hideSegCost = (row.model == "Al minuto" or row.model == "A blocchi (custom)")
            local segCostStr  = (row.model == "Forfait") and "compreso nel forfait"
                                or (hideSegCost and "" or (segCost and string.format("%.2f", segCost) or "DA DEFINIRE"))
            f:write(string.format('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n',
                row.mediaName, row.mediaType or "Video", row.dbName, row.model,
                seg.srcIn or "", seg.srcOut or "",
                durSrc,
                seg.tlIn or "", seg.tlOut or "",
                durMontato,
                segCostStr, note))
        end
        if row.segmentCount > 1 then
            local rowCostStr = row.cost and string.format("%.2f", row.cost) or "DA DEFINIRE"
            f:write(string.format('"  → Subtotale segmenti: %s","","%s","","","","","","","","%s",""\n',
                row.mediaName, row.dbName, rowCostStr))
        end
    end

    f:close()
    return path, nil
end

-- buildExportJSON: serializza tutti i dati in JSON per RepertoireDB_xlsx.py
local function buildExportJSON(rows, byDB, byDur, dbFinalCost, dbDiscountNote,
        grandTotal, grandFrames, timelineName, fps, dbCostBase, dbRoundNote,
        dbEntryByName, excessByDB, audioTotal, undefinedBanks, sortByBank,
        dbUncoveredSec, dbTotalSec)

    local data = {
        version        = SCRIPT_VERSION,
        timelineName   = timelineName,
        fps            = fps,
        -- valuta scelta dall'utente: nel foglio Excel finisce nel formato
        -- delle celle, non nel testo, così le formule continuano a calcolare
        currencySymbol = Settings.cur(),
        currencyCode   = Settings.code(),
        sortByBank     = sortByBank,
        generated      = os.date("%Y-%m-%d %H:%M:%S"),
        grandTotal     = grandTotal,
        grandFrames    = grandFrames,
        audioTotal     = audioTotal or 0,
        byDB           = byDB           or {},
        byDur          = byDur          or {},
        dbFinalCost    = dbFinalCost    or {},
        dbDiscountNote = dbDiscountNote or {},
        dbCostBase     = dbCostBase     or {},
        dbRoundNote    = dbRoundNote    or {},
        dbTotalSec     = dbTotalSec     or {},
        undefinedBanks = {},
        excessByDB     = {},
        dbUncoveredSec = {},
        dbEntryByName  = {},
        rows           = {},
    }

    if undefinedBanks then
        for k in pairs(undefinedBanks) do data.undefinedBanks[k] = true end
    end
    if excessByDB then
        for k, v in pairs(excessByDB) do
            data.excessByDB[k] = { durStr = v.durStr or "", cost = v.cost or 0 }
        end
    end
    if dbUncoveredSec then
        for k, v in pairs(dbUncoveredSec) do
            data.dbUncoveredSec[k] = v
        end
    end
    if dbTotalSec then
        for k, v in pairs(dbTotalSec) do
            data.dbTotalSec[k] = v
        end
    end
    if dbEntryByName then
        for k, e in pairs(dbEntryByName) do
            data.dbEntryByName[k] = {
                mediaType = e.mediaType or "Video",
                model     = e.model     or "",
                rate      = e.rate,
                blockSec  = e.blockSec,
                utilMin   = e.utilMin,
            }
        end
    end

    for _, row in ipairs(rows) do
        local r = {
            mediaName    = row.mediaName    or "",
            mediaType    = row.mediaType    or "Video",
            dbName       = row.dbName       or "",
            model        = row.model        or "",
            cost         = row.cost,
            segmentCount = row.segmentCount or 1,
            segments     = {},
        }
        local hideSegCost = (row.model == "Al minuto" or row.model == "A blocchi (custom)")
        for segIdx, seg in ipairs(row.segments) do
            local segCost = nil
            local note    = ""
            if not hideSegCost then
                if row.model == "A clip" then
                    segCost = (segIdx == 1) and row.cost or 0
                    if segIdx > 1 then note = "incluso nel primo utilizzo" end
                else
                    local ds = seg.dupStatus or "nuovo"
                    if ds == "duplicato" then
                        segCost = 0
                        note = string.format("⚠ RIPETUTO — %s già conteggiati (src %s→%s)",
                            framesToDur(seg.sourceFrames or 0, seg.srcFps or fps),
                            seg.srcIn or "?", seg.srcOut or "?")
                    elseif ds == "parziale" then
                        segCost = 0
                        note = string.format("⚠ PARZIALMENTE RIPETUTO — %d frame unici su %d (src %s→%s)",
                            seg.uniqueFrames or 0, seg.totalFrames or 0,
                            seg.srcIn or "?", seg.srcOut or "?")
                    else
                        segCost = calcCostProportional(row.dbEntry, seg.uniqueSec or seg.sourceSec or 0)
                    end
                end
            end
            if seg.retimeType then
                note = (note ~= "" and (note .. "  |  ") or "") .. seg.retimeType
            end
            local durSrc     = framesToDur(seg.sourceFrames or 0, seg.srcFps or fps)
            local durMontato = framesToDur(math.floor((seg.timelineSec or seg.sourceSec or 0) * fps + 0.5), fps)

            -- Fotogrammi NON già conteggiati altrove: zero se il segmento è
            -- tutto ripetuto, la sola parte nuova se è ripetuto in parte.
            -- È la quantità su cui il motore fattura, e finora restava dentro
            -- il Calculator: nel JSON usciva solo la durata totale, e il foglio
            -- Excel sommava anche i duplicati.
            local frUnici = seg.uniqueFrames
            if frUnici == nil then
                frUnici = (seg.dupStatus == "duplicato") and 0 or (seg.sourceFrames or 0)
            end

            table.insert(r.segments, {
                srcIn       = seg.srcIn      or "",
                srcOut      = seg.srcOut     or "",
                tlIn        = seg.tlIn       or "",
                tlOut       = seg.tlOut      or "",
                durSrc      = durSrc,
                durMontato  = durMontato,
                segCost     = segCost,
                hideSegCost = hideSegCost,
                note        = note,
                dupStatus   = seg.dupStatus  or "nuovo",
                frUnici     = frUnici,
            })
        end
        table.insert(data.rows, r)
    end

    return json.encode(data)
end

-- ============================================================
-- STATO CONDIVISO
-- ============================================================
local lastRows, lastByDB, lastByDur, lastDbFinalCost, lastDbDiscountNote
local lastGrandTotal, lastGrandFrames, lastTLName, lastFps
local lastDbCostBase, lastDbRoundNote, lastDbEntryByName
local lastExcessByDB     = {}
local lastAudioTotal     = 0
local lastUndefinedBanks = {}
-- Durate e secondi scoperti per banca: servono all'export Excel, che con
-- questi due compone la frase "Min Xs - Usati Ys - Scoperti Zs". Vanno
-- dichiarati qui come gli altri: senza local diventano variabili globali
-- nello stato Lua di Resolve, condiviso fra gli script.
local lastDbTotalSec     = {}
local lastDbUncoveredSec = {}
lastFps = 25

-- ============================================================
-- UI
-- ============================================================
local function openReadmeFile()
    local path = getReadmePath()
    -- Verifica se il file esiste
    local f = io.open(path, "r")
    if not f then
        return false, "README non trovato: " .. path
    end
    f:close()

    -- Apre il file con l'editor di sistema
    local sep = package.config:sub(1,1)
    local cmd
    if sep == "\\" then
        -- Windows: notepad
        cmd = 'notepad "' .. path .. '"'
    else
        local osType = io.popen("uname"):read("*a"):match("Darwin") and "mac" or "linux"
        if osType == "mac" then
            -- macOS: open con TextEdit
            cmd = 'open -e "' .. path .. '"'
        else
            -- Linux: xdg-open o gedit
            cmd = 'xdg-open "' .. path .. '" || gedit "' .. path .. '"'
        end
    end

    local ok = os.execute(cmd)
    return ok == 0 or ok == true, ok
end

local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local function buildCalcWindow()
    local win = disp:AddWindow({
        ID = "DBCalc",
        WindowTitle = "RepertoireDB v" .. SCRIPT_VERSION .. " — Calcolatore Costi Repertorio  |  © Tommaso Feraboli Film Editor",
        Geometry = { 100, 100, 1100, 720 },
        MinimumSize = { 1080, 700 },
        ui:VGroup{
            ui:HGroup{
                ui:Label{ Text = "RepertoireDB v" .. SCRIPT_VERSION,
                    Font = ui:Font{ PixelSize = 20 },
                    StyleSheet = "color: #DCDCDC;" },
                ui:HGap{},
                ui:VGroup{
                    Weight = 0,
                    ui:Label{ Text = "© Tommaso Feraboli Film Editor",
                        Alignment = { AlignRight = true },
                        Font = ui:Font{ PixelSize = 13 },
                        StyleSheet = "color: #D2D2D2;" },
                    ui:Label{ Text = "Licenza MIT",
                        Alignment = { AlignRight = true },
                        Font = ui:Font{ PixelSize = 10, Italic = true },
                        StyleSheet = "color: #828282; margin-top: 0px;" },
                },
            },
            ui:HGroup{
                ui:Label{ Text="Timeline:", MinimumSize={70,20} },
                ui:ComboBox{ ID="TimelineCombo", MinimumSize={300,24} },
                ui:HGap{},
                ui:Label{ Text="Ordinamento:", MinimumSize={90,20} },
                ui:ComboBox{ ID="ViewMode", MinimumSize={210,24} },
            },
            ui:HGroup{
                ui:HGap{},
                ui:Button{ ID="BtnCalc", Text="▶  CALCOLA", MinimumSize={140,32} },
            },
            ui:Tree{
                ID = "ResultTree",
                RootIsDecorated = false,
                AlternatingRowColors = true,
                SelectionMode = "NoSelection",
                SortingEnabled = true,
                MinimumSize = { 960, 380 },
            },
            ui:HGroup{
                ui:Label{ ID="LblTotal", Text="Totale: —",
                    Font = ui:Font{ PixelSize = 15, Bold = true } },
                ui:HGap{},
                -- L'etichetta nomina entrambi i formati: il pulsante apre un
                -- dialogo che offre CSV ed Excel, e dire solo "CSV" nascondeva
                -- metà di quello che fa.
                ui:Button{ ID="BtnExport", Text="Esporta CSV / XLSX", MinimumSize={180,32}, Enabled=false },
                ui:VGroup{ Spacing=1,
                    ui:Button{ ID="BtnReadme", Text="📖", MinimumSize={80,52},
                        ToolTip="Apre il file README",
                        StyleSheet=[[QPushButton{font-size:48px;background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #8B7B1A,stop:1 #5A4E0A);color:#FFE97A;border-radius:5px;border:1px solid #5A4E0A;}QPushButton:hover{background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #A08A20,stop:1 #8B7B1A);}]] },
                    ui:Label{ Text="Guida", Alignment={AlignHCenter=true},
                        StyleSheet="color:#8B7B1A; font-size:10px; margin:0;" },
                },
                ui:VGroup{ Spacing=1,
                    ui:Button{ ID="BtnCoffee", Text="☕", MinimumSize={80,52},
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
            ui:Label{ ID="LblStatus",  Text="" },
            ui:Label{ ID="LblUnknown", Text="", WordWrap=true },
        },
    })

    -- Stato locale per re-render al cambio vista
    local lastUnknownClips = {}

    -- Popola timeline combo
    local resolve    = app:GetResolve()
    local project    = resolve:GetProjectManager():GetCurrentProject()
    local timelines  = {}
    local tlCount    = project:GetTimelineCount()
    local combo      = win:Find("TimelineCombo")
    for i = 1, tlCount do
        local tl = project:GetTimelineByIndex(i)
        table.insert(timelines, tl)
        combo:AddItem(tl:GetName())
    end
    local currentTL = project:GetCurrentTimeline()
    if currentTL then
        for i, tl in ipairs(timelines) do
            if tl:GetName() == currentTL:GetName() then
                combo.CurrentIndex = i - 1 break
            end
        end
    end

    -- Popola ViewMode combo
    local viewCombo = win:Find("ViewMode")
    viewCombo:AddItem("Per banca")
    viewCombo:AddItem("Ordine di montaggio")

    local function refreshTree(rows, byDB, byDur, dbFinalCost, dbDiscountNote,
                               grandTotal, grandFrames, fps, unknownClips,
                               dbCostBase, dbRoundNote, dbEntryByName)
        local tree = win:Find("ResultTree")
        tree:Clear()

        -- Intestazione colonne
        local hdr = tree:NewItem()
        hdr.Text[0] = "File sorgente"
        hdr.Text[1] = "Banca dati"
        hdr.Text[2] = "Modello"
        hdr.Text[3] = "TL In"
        hdr.Text[4] = "TL Out"
        hdr.Text[5] = "Costo " .. CUR
        hdr.Text[6] = "Dettaglio"
        hdr.Text[7] = "Inutilizzati"
        tree:SetHeaderItem(hdr)
        tree.ColumnCount = 8
        tree:SetColumnWidth(0, 175)
        tree:SetColumnWidth(1, 110)
        tree:SetColumnWidth(2, 100)
        tree:SetColumnWidth(3, 88)
        tree:SetColumnWidth(4, 88)
        tree:SetColumnWidth(5, 80)
        tree:SetColumnWidth(6, 265)
        tree:SetColumnWidth(7, 120)

        local grandDurStr = framesToDur(grandFrames or 0, fps)

        -- ── RIEPILOGO PER CATEGORIA (sempre in cima) ─────────────────
        local dbNames = {}
        for k in pairs(byDB) do table.insert(dbNames, k) end
        table.sort(dbNames)

        -- Conta clip per banca (per foto/giornali)
        local clipCountByDB = {}
        for _, row in ipairs(rows) do
            clipCountByDB[row.dbName] = (clipCountByDB[row.dbName] or 0) + 1
        end

        -- Raggruppa banche per categoria
        local cats = { "Video", "Fotografie", "Giornali" }
        local byCategory = { Video={}, Fotografie={}, Giornali={} }
        for _, name in ipairs(dbNames) do
            local mt = (dbEntryByName and dbEntryByName[name] and dbEntryByName[name].mediaType) or "Video"
            if byCategory[mt] then table.insert(byCategory[mt], name)
            else table.insert(byCategory["Video"], name) end
        end

        local rHead = tree:NewItem()
        rHead.Text[0] = "RIEPILOGO"
        rHead.Font[0] = ui:Font{ Bold=true }
        tree:AddTopLevelItem(rHead)

        local grandVideoFr = 0

        for _, cat in ipairs(cats) do
            local names = byCategory[cat]
            if #names > 0 then
                -- Header categoria
                local catRow = tree:NewItem()
                catRow.Text[0] = "  ▸ " .. cat:upper()
                catRow.Font[0] = ui:Font{ Bold=true }
                tree:AddTopLevelItem(catRow)

                local subtot      = 0
                local subtotDurFr = 0
                local subtotClips = 0

                for _, name in ipairs(names) do
                    local net    = dbFinalCost and dbFinalCost[name]
                    local base   = dbCostBase  and dbCostBase[name]
                    local hasDisc = net and base and math.abs(net - base) > 0.005
                    if net then subtot = subtot + net end

                    local it = tree:NewItem()
                    it.Text[0] = "    " .. name
                    it.Text[5] = net and string.format("%.2f", net) or "DA DEFINIRE"
                    it.Font[0] = ui:Font{ Bold=true }
                    it.Font[5] = ui:Font{ Bold=true }

                    if cat == "Video" then
                        local durStr  = framesToDur(byDur and byDur[name] or 0, fps)
                        subtotDurFr   = subtotDurFr + (byDur and byDur[name] or 0)
                        it.Text[6] = durStr .. (hasDisc and ("  [lordo " .. Settings.money(base) .. "]") or "")
                        -- Badge secondi inutilizzati per banca
                        local entry = dbEntryByName and dbEntryByName[name]
                        local prop  = byDB and byDB[name] or 0
                        if base and entry and base > prop + 0.005 then
                            local extraCost = base - prop
                            local unusedSec = 0
                            if entry.model == "Al minuto" and entry.rate and entry.rate > 0 then
                                unusedSec = math.floor(extraCost / (entry.rate / 60) + 0.5)
                            elseif entry.model == "A blocchi (custom)" and entry.rate and entry.rate > 0 then
                                local blockSec = entry.blockSec or 30
                                unusedSec = math.floor(extraCost / (entry.rate / blockSec) + 0.5)
                            end
                            if unusedSec > 0 then
                                it.Text[7] = string.format("⚠ %ds inut. →%s", unusedSec, Settings.money(extraCost))
                            end
                        end
                    else
                        local nc    = clipCountByDB[name] or 0
                        subtotClips = subtotClips + nc
                        it.Text[6] = nc .. " clip" .. (hasDisc and ("  [lordo " .. Settings.money(base) .. "]") or "")
                    end
                    tree:AddTopLevelItem(it)

                    if dbDiscountNote and dbDiscountNote[name] then
                        local d = tree:NewItem()
                        d.Text[0] = "      ↳ " .. dbDiscountNote[name]
                        d.Font[0] = ui:Font{ Italic=true }
                        tree:AddTopLevelItem(d)
                    end
                    if dbRoundNote and dbRoundNote[name] then
                        local rn = tree:NewItem()
                        rn.Text[0] = "      ↳ " .. dbRoundNote[name]
                        rn.Font[0] = ui:Font{ Italic=true }
                        tree:AddTopLevelItem(rn)
                    end
                end

                -- Subtotale categoria
                local sub = tree:NewItem()
                sub.Text[0] = "    Subtotale " .. cat
                sub.Text[5] = string.format("%.2f", subtot)
                sub.Font[0] = ui:Font{ Bold=true }
                sub.Font[5] = ui:Font{ Bold=true }
                if cat == "Video" then
                    sub.Text[6] = framesToDur(subtotDurFr, fps)
                    grandVideoFr = grandVideoFr + subtotDurFr
                else
                    sub.Text[6] = subtotClips .. " clip tot."
                end
                tree:AddTopLevelItem(sub)
            end
        end

        -- ── AUDIO ECCEDENTE ─────────────────────────────────────────
        local audioEx  = lastExcessByDB or {}
        local audioTot = lastAudioTotal  or 0
        if next(audioEx) then
            local aHead = tree:NewItem()
            aHead.Text[0] = "  ▸ AUDIO ECCEDENTE"
            aHead.Font[0] = ui:Font{ Bold=true }
            tree:AddTopLevelItem(aHead)

            local audioNames = {}
            for k in pairs(audioEx) do table.insert(audioNames, k) end
            table.sort(audioNames)

            for _, name in ipairs(audioNames) do
                local ex = audioEx[name]
                local it = tree:NewItem()
                it.Text[0] = "    " .. name
                it.Text[5] = ex.cost and string.format("%.2f", ex.cost) or "DA DEFINIRE"
                it.Text[6] = ex.durStr .. "  · 50% tariffa piena · no sconti"
                it.Font[0] = ui:Font{ Bold=true }
                it.Font[5] = ui:Font{ Bold=true }
                tree:AddTopLevelItem(it)
            end

            if #audioNames > 1 then
                local sub = tree:NewItem()
                sub.Text[0] = "    Subtotale Audio Eccedente"
                sub.Text[5] = string.format("%.2f", audioTot)
                sub.Font[0] = ui:Font{ Bold=true }
                sub.Font[5] = ui:Font{ Bold=true }
                tree:AddTopLevelItem(sub)
            end
        end

        -- Riga totale generale
        local totRow = tree:NewItem()
        totRow.Text[0] = "  TOTALE GENERALE"
        totRow.Text[5] = string.format("%.2f", grandTotal + audioTot)
        totRow.Text[6] = framesToDur(grandVideoFr, fps)
            .. (audioTot > 0 and ("  · audio eccedente " .. Settings.money(audioTot)) or "")
        totRow.Font[0] = ui:Font{ Bold=true }
        totRow.Font[5] = ui:Font{ Bold=true }
        tree:AddTopLevelItem(totRow)

        -- ── Warning banche senza tariffa ────────────────────────────
        local undefBanks = lastUndefinedBanks or {}
        local undefNames = {}
        for k in pairs(undefBanks) do table.insert(undefNames, k) end
        if #undefNames > 0 then
            table.sort(undefNames)
            local wRow = tree:NewItem()
            wRow.Text[0] = "  ⚠ Ancora da definire i costi di: " .. table.concat(undefNames, ", ")
            wRow.Font[0] = ui:Font{ Italic=true }
            tree:AddTopLevelItem(wRow)
        end

        -- ── Separatore ───────────────────────────────────────────────
        local sepLine = tree:NewItem()
        sepLine.Text[0] = string.rep("─", 80)
        tree:AddTopLevelItem(sepLine)

        -- ── DETTAGLIO clip ───────────────────────────────────────────
        local viewMode = win:Find("ViewMode").CurrentIndex  -- 0=per banca, 1=ordine montaggio

        local dHead = tree:NewItem()
        dHead.Text[0] = viewMode == 0 and "DETTAGLIO PER BANCA"
                                       or "DETTAGLIO — ORDINE DI MONTAGGIO"
        dHead.Font[0] = ui:Font{ Bold=true }
        tree:AddTopLevelItem(dHead)

        -- Copia e ordina le righe secondo la vista selezionata
        local sorted = {}
        for _, r in ipairs(rows) do table.insert(sorted, r) end

        if viewMode == 0 then
            -- Alfabetico per banca, poi per nome file
            table.sort(sorted, function(a, b)
                if a.dbName ~= b.dbName then return a.dbName < b.dbName end
                return a.mediaName < b.mediaName
            end)
        else
            -- Cronologico: primo segmento per TL In
            table.sort(sorted, function(a, b)
                local aF = a.segments and a.segments[1]
                        and tcToFrames(a.segments[1].tlIn or "00:00:00:00", fps) or 0
                local bF = b.segments and b.segments[1]
                        and tcToFrames(b.segments[1].tlIn or "00:00:00:00", fps) or 0
                return aF < bF
            end)
        end

        local currentDB = ""
        for _, row in ipairs(sorted) do
            -- Separatore di banca solo nella vista "Per banca"
            if viewMode == 0 and row.dbName ~= currentDB then
                currentDB = row.dbName
                local sep = tree:NewItem()
                sep.Text[0] = "  ── " .. row.dbName .. " ──"
                sep.Font[0] = ui:Font{ Bold=true }
                tree:AddTopLevelItem(sep)
            end

            local multiSeg = #row.segments > 1
            local firstSeg = row.segments and row.segments[1]
            local it = tree:NewItem()
            it.Text[0] = row.mediaName .. (row.hasDuplicates and "  ⚠" or "")
            it.Text[1] = row.dbName
            it.Text[2] = row.model
            it.Text[3] = firstSeg and (firstSeg.tlIn  or "") or ""
            it.Text[4] = firstSeg and (firstSeg.tlOut or "") or ""
            it.Text[5] = row.cost and string.format("%.2f", row.cost) or "DA DEFINIRE"
            it.Text[6] = row.detail
            tree:AddTopLevelItem(it)

            -- Sub-righe per clip usate più volte in timeline
            if multiSeg then
                for segIdx, seg in ipairs(row.segments) do
                    local sub    = tree:NewItem()
                    local durStr = framesToDur(seg.sourceFrames or 0, seg.srcFps or fps)
                    local ds     = seg.dupStatus or "nuovo"
                    local status
                    if ds == "duplicato" then
                        status = "⚠ RIPETUTO — non conteggiato"
                    elseif ds == "parziale" then
                        status = string.format("⚠ parziale — %s unici su %s",
                            framesToDur(seg.uniqueFrames or 0, seg.srcFps or fps), durStr)
                    else
                        status = "src: " .. (seg.srcIn or "?") .. " → " .. (seg.srcOut or "?")
                    end
                    local rtInfo = seg.retimeType and ("  [" .. seg.retimeType .. "]") or ""
                    sub.Text[0] = string.format("    ↳ uso %d/%d", segIdx, #row.segments)
                    sub.Text[3] = seg.tlIn  or ""
                    sub.Text[4] = seg.tlOut or ""
                    sub.Text[5] = ds == "duplicato" and "—" or ""
                    sub.Text[6] = durStr .. rtInfo .. "   " .. status
                    if ds ~= "nuovo" then
                        sub.Font[0] = ui:Font{ Italic=true }
                        sub.Font[6] = ui:Font{ Italic=true }
                    end
                    tree:AddTopLevelItem(sub)
                end
            end
        end

        local audioTotLabel = lastAudioTotal or 0
        local undefWarn     = {}
        for k in pairs(lastUndefinedBanks or {}) do table.insert(undefWarn, k) end
        table.sort(undefWarn)
        local baseLabel = audioTotLabel > 0
            and string.format("TOTALE: %s  (video %s + audio eccedente %s)  |  Durata video: %s",
                Settings.moneySpaced(grandTotal + audioTotLabel), Settings.money(grandTotal), Settings.money(audioTotLabel), grandDurStr)
            or  string.format("TOTALE: %s  |  Durata: %s", Settings.moneySpaced(grandTotal), grandDurStr)
        if #undefWarn > 0 then
            baseLabel = baseLabel .. "   ⚠ Ancora da definire i costi di: " .. table.concat(undefWarn, ", ")
        end
        win:Find("LblTotal").Text = baseLabel
        win:Find("BtnExport").Enabled = true

        local unknownList = {}
        for k in pairs(unknownClips) do table.insert(unknownList, k) end
        win:Find("LblUnknown").Text = #unknownList > 0
            and ("⚠ Tag non trovati in config: " .. table.concat(unknownList, ", "))
            or  ""
    end

    win.On.BtnCalc.Clicked = function(ev)
        local db = loadDB()
        if #db == 0 then
            win:Find("LblStatus").Text = "⚠ Nessuna banca dati configurata. Avvia prima RepertoireDB_Config."
            return
        end
        local dbMap = dbByName(db)

        local tlIdx    = win:Find("TimelineCombo").CurrentIndex + 1
        local timeline = timelines[tlIdx]
        if not timeline then
            win:Find("LblStatus").Text = "⚠ Nessuna timeline selezionata."
            return
        end

        local fpsStr = timeline:GetSetting("timelineFrameRate")
        local fps    = tonumber(fpsStr) or 25
        if math.abs(fps - 29.97) < 0.1 then fps = 30000/1001 end
        if math.abs(fps - 59.94) < 0.1 then fps = 60000/1001 end

        LogManager:info("Calculator.lua", "Timeline aperta - calcolo costi avviato: " .. timeline:GetName())
        win:Find("LblStatus").Text = string.format("Analisi '%s' @ %.3f fps...", timeline:GetName(), fps)

        local results, unknownClips      = scanTimeline(timeline, dbMap, fps)
        local audioGroups                = scanAudio(timeline, dbMap, fps)
        local excessByDB, audioTotal     = calcExcessAudio(results, audioGroups, fps)

        local rows, byDB, byDur, dbFinalCost, dbDiscountNote, dbTotalSec,
              grandTotal, grandFrames, dbCostBase, dbRoundNote, dbEntryByName, undefinedBanks, dbUncoveredSec =
            aggregateCosts(results, fps)

        lastRows           = rows
        lastByDB           = byDB
        lastByDur          = byDur
        lastDbFinalCost    = dbFinalCost
        lastDbDiscountNote = dbDiscountNote
        lastGrandTotal     = grandTotal
        lastGrandFrames    = grandFrames
        lastTLName         = timeline:GetName()
        lastFps            = fps
        lastDbCostBase     = dbCostBase
        lastDbRoundNote    = dbRoundNote
        lastDbEntryByName  = dbEntryByName
        lastExcessByDB     = excessByDB
        lastAudioTotal     = audioTotal
        lastUndefinedBanks = undefinedBanks or {}
        lastUnknownClips   = unknownClips or {}
        lastDbUncoveredSec = dbUncoveredSec or {}
        lastDbTotalSec     = dbTotalSec     or {}

        refreshTree(rows, byDB, byDur, dbFinalCost, dbDiscountNote,
                    grandTotal, grandFrames, fps, unknownClips,
                    dbCostBase, dbRoundNote, dbEntryByName)
        win:Find("BtnExport").Enabled = true
        LogManager:info("Calculator.lua", "Calcolo completato - Totale: " .. Settings.money(grandTotal) .. " | Clip trovate: " .. #rows)
        win:Find("LblStatus").Text = string.format("Completato — %d clip sorgente trovate.", #rows)
    end

    -- Cambio vista: rirende il tree con i dati già calcolati
    win.On.ViewMode.CurrentIndexChanged = function(ev)
        if not lastRows then return end
        refreshTree(lastRows, lastByDB, lastByDur, lastDbFinalCost, lastDbDiscountNote,
                    lastGrandTotal, lastGrandFrames, lastFps, lastUnknownClips,
                    lastDbCostBase, lastDbRoundNote, lastDbEntryByName)
    end

    win.On.BtnExport.Clicked = function(ev)
        if not lastRows then return end

        -- Dialogo opzioni esportazione
        local exportOpts = { cancelled = true, sortByBank = false, formatXLSX = false }
        local dlg = disp:AddWindow({
            ID = "ExportOptDlg",
            WindowTitle = "Esporta — Opzioni",
            Geometry = { 430, 280, 420, 155 },
            ui:VGroup{
                ui:HGroup{
                    ui:Label{ Text = "Formato:", MinimumSize={130,22} },
                    ui:ComboBox{ ID = "FmtCombo", MinimumSize={260,24} },
                },
                ui:HGroup{
                    ui:Label{ Text = "Ordine sezione Segmenti:", MinimumSize={130,22} },
                    ui:ComboBox{ ID = "SortCombo", MinimumSize={260,24} },
                },
                ui:HGroup{
                    ui:HGap{},
                    ui:Button{ ID = "BtnDoExport",    Text = "Esporta…", MinimumSize={120,30} },
                    ui:Button{ ID = "BtnCancelExport", Text = "Annulla",  MinimumSize={120,30} },
                },
            },
        })
        local fmtCombo  = dlg:Find("FmtCombo")
        local sortCombo = dlg:Find("SortCombo")
        fmtCombo:AddItem("CSV (.csv)")
        fmtCombo:AddItem("Excel (.xlsx)  — richiede Python + openpyxl")
        sortCombo:AddItem("Ordine di montaggio")
        sortCombo:AddItem("Per banca dati")

        dlg.On.BtnDoExport.Clicked = function()
            exportOpts.formatXLSX = (fmtCombo.CurrentIndex == 1)
            exportOpts.sortByBank = (sortCombo.CurrentIndex == 1)
            exportOpts.cancelled  = false
            disp:ExitLoop()
        end
        dlg.On.BtnCancelExport.Clicked = function() disp:ExitLoop() end
        dlg.On.ExportOptDlg.Close      = function() disp:ExitLoop() end

        dlg:Show()
        disp:RunLoop()
        dlg:Hide()

        if exportOpts.cancelled then
            win:Find("LblStatus").Text = "Esportazione annullata."
            return
        end

        -- ── CSV ─────────────────────────────────────────────────────────────
        if not exportOpts.formatXLSX then
            local path, err = exportCSV(lastRows, lastByDB, lastByDur, lastDbFinalCost,
                lastDbDiscountNote, lastGrandTotal, lastGrandFrames, lastTLName, lastFps,
                lastDbCostBase, lastDbRoundNote, lastDbEntryByName,
                lastExcessByDB, lastAudioTotal, lastUndefinedBanks, exportOpts.sortByBank, lastDbUncoveredSec)
            if err then
                LogManager:error("Calculator.lua", "Export CSV fallito: " .. err)
                win:Find("LblStatus").Text = "⚠ " .. err
            else
                LogManager:info("Calculator.lua", "Export CSV completato - " .. #lastRows .. " righe scritte: " .. path)
                win:Find("LblStatus").Text = "✓ CSV: " .. path
            end
            return
        end

        -- ── XLSX ─────────────────────────────────────────────────────────────
        -- Scrive JSON temporaneo
        local tmpDir  = (os.getenv("TMPDIR") or "/tmp"):gsub("[/\\]$", "")
        local tmpJson = tmpDir .. "/RepertoireDB_export_tmp.json"
        local jf = io.open(tmpJson, "w")
        if not jf then
            win:Find("LblStatus").Text = "⚠ Impossibile scrivere file temporaneo in " .. tmpDir
            return
        end
        jf:write(buildExportJSON(lastRows, lastByDB, lastByDur, lastDbFinalCost,
            lastDbDiscountNote, lastGrandTotal, lastGrandFrames, lastTLName, lastFps,
            lastDbCostBase, lastDbRoundNote, lastDbEntryByName,
            lastExcessByDB, lastAudioTotal, lastUndefinedBanks, exportOpts.sortByBank,
            lastDbUncoveredSec, lastDbTotalSec))
        jf:close()

        -- Chiede cartella di destinazione
        local home    = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
        local dir = fu:RequestDir(home .. "/Desktop")
        if not dir or dir == "" then
            os.remove(tmpJson)
            win:Find("LblStatus").Text = "Esportazione annullata."
            return
        end
        if not dir:match("[/\\]$") then dir = dir .. "/" end
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local outPath = dir .. "RepertoireDB_" .. lastTLName:gsub("[^%w]", "_") .. "_" .. timestamp .. ".xlsx"

        -- Chiama Python
        local pyScript = getScriptDir() .. "RepertoireDB_xlsx.py"
        local sep = package.config:sub(1,1)
        local python = (sep == "\\") and "python" or "python3"
        local cmd = string.format('%s "%s" "%s" "%s" 2>&1', python, pyScript, tmpJson, outPath)
        local h   = io.popen(cmd)
        local out = h and h:read("*a") or ""
        if h then h:close() end
        os.remove(tmpJson)

        if out:match("^OK:") then
            LogManager:info("Calculator.lua", "Export XLSX avviato - RepertoireDB_xlsx.py eseguito con successo")
            win:Find("LblStatus").Text = "✓ XLSX: " .. outPath
        elseif out:match("^ERR:openpyxl") then
            LogManager:error("Calculator.lua", "Export XLSX fallito - openpyxl non installato nel PATH")
            LogManager:info("Calculator.lua", "Fallback: export CSV completato come alternativa")
            win:Find("LblStatus").Text = "⚠ openpyxl non installato — esegui: pip3 install openpyxl"
        elseif out:match("^ERR:") then
            LogManager:error("Calculator.lua", "Export XLSX fallito - Python error: " .. (out:match("^ERR:(.-)[\n\r]") or out))
            win:Find("LblStatus").Text = "⚠ " .. (out:match("^ERR:(.-)[\n\r]") or out)
        else
            LogManager:error("Calculator.lua", "Export XLSX fallito - python3 non disponibile nel PATH")
            LogManager:info("Calculator.lua", "Fallback: export CSV completato come alternativa")
            win:Find("LblStatus").Text = "⚠ Errore Python: " .. (out:sub(1, 120) or "(nessun output)")
        end
    end

    win.On.BtnCoffee.Clicked = function(ev)
        openURL("https://paypal.me/acoffeefortom")
    end

    win.On.BtnBug.Clicked = function(ev)
        reportBug("RepertoireDB_Calculator.lua", SCRIPT_VERSION)
    end

    win.On.BtnReadme.Clicked = function(ev)
        local ok, result = openReadmeFile()
        if ok then
            win:Find("LblStatus").Text = "✓ README.txt aperto nel tuo editor di testo."
        else
            win:Find("LblStatus").Text = "⚠ Impossibile aprire README.txt: " .. tostring(result)
        end
    end

    win.On.DBCalc.Close = function(ev) disp:ExitLoop() end

    return win
end

-- ============================================================
-- MAIN
-- ============================================================
local win = buildCalcWindow()
win:Show()
disp:RunLoop()
win:Hide()
