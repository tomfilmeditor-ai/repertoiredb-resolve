-- ==============================================================
-- Settings.lua — Impostazioni condivise fra gli script RepertoireDB
-- (Lua 5.1, come il Lua incorporato in DaVinci Resolve)
--
-- Contiene la valuta, la lingua dell'interfaccia e le etichette dei
-- valori di dominio (modelli di pricing, tipi di media, tipi di
-- sconto). È un modulo a sé perché i tre script leggono la
-- configurazione ognuno per conto proprio, e serviva un punto
-- comune: lo stesso schema di LogManager e BugReportDialog.
--
-- Il file delle impostazioni è separato da repertoire_db.json, che
-- resta una lista di banche dati: così i database già esistenti non
-- vengono toccati, e se il file manca si assume euro e italiano.
--
-- ATTENZIONE, LEGGERE PRIMA DI TRADURRE QUALCOSA IN QUESTO FILE:
-- i valori di dominio qui sotto (MODELS, MEDIA_TYPES, DISCOUNT_TYPES)
-- sono CHIAVI TECNICHE, non testo da tradurre. Sono scritti in
-- italiano per ragioni storiche: sono il contenuto del campo "model"
-- e "mediaType" in repertoire_db.json (75 banche dati nei database
-- reali), delle configurazioni salvate in memories/, e della colonna
-- Model nei CSV di importazione, che è un formato pubblico già
-- distribuito e documentato nel manuale.
-- Tradurli romperebbe i database esistenti e i CSV già in mano agli
-- utenti. Quello che si traduce sono le ETICHETTE, nelle tabelle
-- LABELS più sotto. Vedi STATO.md, sessione del 30 ottobre 2026.
--
-- Autore: Tommaso Feraboli — Film Editor
-- Licenza MIT
-- ==============================================================

local Settings = {}

local DEFAULT_SYMBOL = "€"
local DEFAULT_CODE   = "EUR"
local DEFAULT_LANG   = "it"

-- Valute offerte nel menu. Il codice serve a distinguere i casi in cui
-- due valute condividono il simbolo (¥ per cinese e giapponese, $ per
-- statunitense, canadese e australiano): nel menu si legge il codice,
-- nell'interfaccia compare il simbolo.
Settings.CURRENCIES = {
    { code = "EUR", symbol = "€",   label = "EUR  €   Euro" },
    { code = "USD", symbol = "$",   label = "USD  $   Dollaro USA" },
    { code = "GBP", symbol = "£",   label = "GBP  £   Sterlina" },
    { code = "CHF", symbol = "CHF", label = "CHF      Franco svizzero" },
    { code = "CAD", symbol = "CA$", label = "CAD  CA$ Dollaro canadese" },
    { code = "AUD", symbol = "A$",  label = "AUD  A$  Dollaro australiano" },
    { code = "CNY", symbol = "¥",   label = "CNY  ¥   Yuan cinese" },
    { code = "JPY", symbol = "¥",   label = "JPY  ¥   Yen giapponese" },
    { code = "KRW", symbol = "₩",   label = "KRW  ₩   Won coreano" },
}

-- Dichiarata qui perché systemLang() la consulta, ma il suo contenuto è
-- definito più sotto: in Lua una variabile locale non è visibile alle
-- funzioni scritte prima della sua dichiarazione, e senza questa riga
-- LABELS risulterebbe una variabile globale inesistente.
local LABELS

-- ── Lingue disponibili ───────────────────────────────────────────
Settings.LANGUAGES = {
    { code = "it", label = "Italiano" },
    { code = "en", label = "English"  },
}

-- Rilevazione della lingua del SISTEMA OPERATIVO, non di quella di Resolve.
-- Sono due impostazioni diverse: Resolve ha la sua, che l'utente può aver
-- messo in inglese pur lavorando su un Mac in italiano o viceversa. Quella
-- che conta è la lingua del sistema, perché è quella che l'utente ha scelto
-- per leggere.
local sysLangCache = nil

function Settings.systemLang()
    if sysLangCache then return sysLangCache end
    sysLangCache = DEFAULT_LANG

    local function run(cmd)
        local h = io.popen(cmd)
        if not h then return nil end
        local out = h:read("*a")
        h:close()
        return out
    end

    local raw
    if package.config:sub(1,1) == "\\" then
        -- Windows: Get-UICulture è la lingua dell'interfaccia. Se PowerShell
        -- non risponde si ripiega sul registro.
        raw = run('powershell -NoProfile -Command "(Get-UICulture).Name" 2>NUL')
        if not (raw and raw:match("%a")) then
            local reg = run('reg query "HKCU\\Control Panel\\International" /v LocaleName 2>NUL')
            -- L'uscita di reg query contiene il percorso della chiave e il
            -- tipo del valore prima del valore stesso:
            --   HKEY_CURRENT_USER\Control Panel\International
            --       LocaleName    REG_SZ    en-GB
            -- Prendendo le prime lettere che capitano si pesca "HK" di HKEY.
            -- Il valore è quello che segue REG_SZ.
            raw = reg and reg:match("REG_SZ%s+(%S+)") or reg
        end
    else
        local osname = run("uname -s 2>/dev/null") or ""
        if osname:match("Darwin") then
            -- AppleLanguages è l'ordine delle lingue dell'INTERFACCIA, che è
            -- quello che l'utente vede nel sistema. AppleLocale invece è il
            -- formato di numeri e date e può essere diverso: un Mac in inglese
            -- con formati italiani è una configurazione comune.
            -- L'uscita è una lista fra parentesi:  (\n  "it-IT",\n  "en-IT"\n)
            -- La prima voce è la lingua preferita.
            local al = run("defaults read -g AppleLanguages 2>/dev/null")
            raw = al and al:match('"([%a%-_]+)"') or al
        end
        -- Linux, o macOS se il comando sopra non ha risposto
        if not (raw and raw:match("%a")) then
            raw = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES")
        end
    end

    local code = raw and raw:lower():match("(%a%a)[%-_]?%a*")
    if code and LABELS[code] then sysLangCache = code end
    return sysLangCache
end

-- ── VALORI DI DOMINIO — chiavi tecniche, non traducibili ─────────
-- Questi sono esattamente i valori che stanno dentro repertoire_db.json
-- e dentro la colonna Model dei CSV di importazione. Non cambiarli.
Settings.MODELS       = { "A clip", "Al secondo", "A blocchi (custom)", "Al minuto", "Forfait" }
Settings.MODELS_MEDIA = { "A clip", "Forfait" }   -- Fotografie e Giornali
Settings.MEDIA_TYPES  = { "Video", "Fotografie", "Giornali" }
Settings.DISCOUNT_TYPES = { "flat", "progressive" }

-- Nomi simbolici, per non ripetere le stringhe nel codice. Usare questi
-- al posto dei letterali: se un confronto è scritto a mano e qualcuno
-- sbaglia una lettera, Lua non se ne accorge e il ramo non scatta mai.
Settings.MODEL = {
    CLIP   = "A clip",
    SECOND = "Al secondo",
    BLOCK  = "A blocchi (custom)",
    MINUTE = "Al minuto",
    FLAT   = "Forfait",
}
Settings.MEDIA = {
    VIDEO = "Video",
    PHOTO = "Fotografie",
    PRESS = "Giornali",
}
Settings.DISCOUNT = {
    FLAT        = "flat",
    PROGRESSIVE = "progressive",
}

-- ── ETICHETTE — questo è ciò che si traduce ──────────────────────
LABELS = {
    it = {
        models = {
            ["A clip"]             = "A clip",
            ["Al secondo"]         = "Al secondo",
            ["A blocchi (custom)"] = "A blocchi (custom)",
            ["Al minuto"]          = "Al minuto",
            ["Forfait"]            = "Forfait",
        },
        media = {
            ["Video"]      = "Video",
            ["Fotografie"] = "Fotografie",
            ["Giornali"]   = "Giornali",
        },
        discounts = {
            flat        = "Flat (su tutto)",
            progressive = "Progressivo (solo eccedenza)",
        },
    },
    en = {
        models = {
            ["A clip"]             = "Per clip",
            ["Al secondo"]         = "Per second",
            ["A blocchi (custom)"] = "Per custom block",
            ["Al minuto"]          = "Per minute",
            ["Forfait"]            = "Flat fee",
        },
        media = {
            ["Video"]      = "Video",
            ["Fotografie"] = "Photos",
            ["Giornali"]   = "Newspapers",
        },
        discounts = {
            flat        = "Flat (on everything)",
            progressive = "Tiered (on the excess only)",
        },
    },
}

local cache = nil

-- Percorso del file impostazioni, accanto al database delle banche dati.
-- Stessa logica di rilevamento sistema operativo usata da getConfigPath()
-- negli script: su Resolve 20/21 con macOS Sonoma io.open() su una
-- directory restituisce nil, quindi si usa uname.
function Settings.getPath()
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        local pd = os.getenv("PROGRAMDATA") or "C:\\ProgramData"
        return pd .. "\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Comp\\RepertoireDB\\repertoire_settings.json"
    end
    local home = os.getenv("HOME") or "."
    local h = io.popen("uname -s 2>/dev/null")
    local osname = h and h:read("*a") or ""
    if h then h:close() end
    if osname:match("Darwin") then
        return home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_settings.json"
    else
        return home .. "/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/repertoire_settings.json"
    end
end

-- Lettura senza dipendere da dkjson: il file ha due sole chiavi, e un
-- modulo di impostazioni che fallisce perché manca una libreria sarebbe
-- peggio del problema che risolve.
function Settings.load()
    if cache then return cache end
    cache = { symbol = DEFAULT_SYMBOL, code = DEFAULT_CODE, lang = "auto" }

    local f = io.open(Settings.getPath(), "r")
    if not f then return cache end          -- file assente: euro e italiano
    local txt = f:read("*a") or ""
    f:close()

    local sym = txt:match('"currency_symbol"%s*:%s*"([^"]*)"')
    local cod = txt:match('"currency_code"%s*:%s*"([^"]*)"')
    local lng = txt:match('"language"%s*:%s*"([^"]*)"')
    if sym and sym ~= "" then cache.symbol = sym end
    if cod and cod ~= "" then cache.code   = cod end
    -- "auto" significa: segui la lingua del sistema. È il valore di partenza,
    -- anche per i file salvati prima che la lingua esistesse, dove la chiave
    -- manca del tutto. Una lingua che non conosciamo non deve svuotare
    -- l'interfaccia: si ricade sull'automatico.
    if lng == "auto" or (lng and LABELS[lng]) then cache.lang = lng end
    return cache
end

-- Scrittura unica del file: così aggiungere una chiave non può far
-- perdere le altre. Settings.save scriveva solo la valuta, e salvando
-- la valuta avrebbe cancellato la lingua.
local function writeFile()
    local path = Settings.getPath()

    -- La directory potrebbe non esistere alla primissima installazione
    local sep = package.config:sub(1,1)
    if sep ~= "\\" then
        os.execute('mkdir -p "' .. path:gsub("/[^/]*$", "") .. '"')
    end

    local f = io.open(path, "w")
    if not f then return false, "Impossibile scrivere: " .. path end
    f:write(string.format(
        '{\n  "currency_symbol": "%s",\n  "currency_code": "%s",\n  "language": "%s"\n}\n',
        cache.symbol, cache.code, cache.lang))
    f:close()
    return true
end

function Settings.save(symbol, code)
    local c = Settings.load()
    c.symbol = symbol or DEFAULT_SYMBOL
    c.code   = code   or DEFAULT_CODE
    return writeFile()
end

function Settings.saveLang(lang)
    local c = Settings.load()
    c.lang = (lang == "auto" or (lang and LABELS[lang])) and lang or "auto"
    return writeFile()
end

-- La scelta salvata: "auto" oppure un codice di lingua. È quella da mostrare
-- selezionata nel menu.
function Settings.langChoice()
    return Settings.load().lang
end

-- La lingua effettivamente in uso: risolve "auto" sulla lingua del sistema.
-- È questa che va usata per decidere cosa scrivere a schermo.
function Settings.lang()
    local c = Settings.load().lang
    if c == "auto" then return Settings.systemLang() end
    return c
end

-- Voci del menu Lingua. La prima dice su cosa è caduta la rilevazione, così
-- "Automatico" non è una scatola chiusa: si vede subito cosa ha scelto.
function Settings.languageOptions()
    local sys  = Settings.systemLang()
    local name = sys
    for _, l in ipairs(Settings.LANGUAGES) do
        if l.code == sys then name = l.label end
    end
    local out = { { code = "auto", label = "Automatico — " .. name } }
    for _, l in ipairs(Settings.LANGUAGES) do
        out[#out + 1] = { code = l.code, label = l.label }
    end
    return out
end

-- ── Etichette ────────────────────────────────────────────────────
-- Se un valore non è in tabella (database modificato a mano, versione
-- futura con un modello in più) si restituisce il valore stesso: meglio
-- mostrare una parola italiana che una cella vuota o un buco nel menu.
local function labelOf(group, value)
    if value == nil or value == "" then return "" end
    local L = LABELS[Settings.lang()] or LABELS[DEFAULT_LANG]
    return (L[group] and L[group][value]) or value
end

function Settings.modelLabel(v)    return labelOf("models",    v) end
function Settings.mediaLabel(v)    return labelOf("media",     v) end
function Settings.discountLabel(v) return labelOf("discounts", v) end

-- Dall'etichetta mostrata al valore da salvare. Serve quando si legge
-- una scelta dall'interfaccia senza poter usare l'indice della lista.
-- Cerca prima nella lingua attiva, poi in tutte: così un'etichetta
-- italiana resta riconoscibile anche con l'interfaccia in inglese.
local function valueOf(group, label)
    if label == nil or label == "" then return nil end
    local order = { Settings.lang() }
    for code in pairs(LABELS) do
        if code ~= order[1] then order[#order + 1] = code end
    end
    for _, code in ipairs(order) do
        local g = LABELS[code][group]
        if g then
            for value, lbl in pairs(g) do
                if lbl == label then return value end
            end
        end
    end
    return label   -- già un valore di dominio, o sconosciuto: si restituisce
end

function Settings.modelValue(l)    return valueOf("models",    l) end
function Settings.mediaValue(l)    return valueOf("media",     l) end
function Settings.discountValue(l) return valueOf("discounts", l) end

-- Liste di etichette, nell'ordine dei valori: l'indice scelto nel menu
-- corrisponde all'indice nella lista dei valori.
local function labelsFor(group, values)
    local out = {}
    for i, v in ipairs(values) do out[i] = labelOf(group, v) end
    return out
end

function Settings.modelLabels(values)
    return labelsFor("models", values or Settings.MODELS)
end
function Settings.mediaLabels()
    return labelsFor("media", Settings.MEDIA_TYPES)
end
function Settings.discountLabels()
    return labelsFor("discounts", Settings.DISCOUNT_TYPES)
end

-- Indice (1-based) di un valore in una lista, 1 se non trovato.
function Settings.indexOf(values, value)
    for i, v in ipairs(values) do if v == value then return i end end
    return 1
end

-- ── Traduzione del testo dell'interfaccia ────────────────────────
-- Le traduzioni stanno in Strings.lua, un modulo generato dal file di
-- traduzione. La chiave è il testo italiano stesso, non un identificativo:
--   * l'italiano resta leggibile nel punto dove viene usato
--   * un identificativo scritto male non può esistere
--   * se una traduzione manca compare l'italiano, non una sigla
--
-- Strings.lua è facoltativo: se non è installato, o è di una versione più
-- vecchia, l'interfaccia resta in italiano senza un errore a schermo. È la
-- ragione per cui l'italiano è passato come secondo argomento e non tenuto
-- dentro il modulo: senza di esso non resterebbe niente da mostrare.
local okStrings, STRINGS = pcall(require, "Strings")
if not okStrings or type(STRINGS) ~= "table" then STRINGS = nil end

function Settings.t(italiano)
    if italiano == nil then return "" end
    if not STRINGS then return italiano end
    local lang = Settings.lang()
    if lang == DEFAULT_LANG then return italiano end
    local tbl = STRINGS[lang]
    local tradotto = tbl and tbl[italiano]
    if tradotto == nil or tradotto == "" then return italiano end
    return tradotto
end

-- true se per la lingua in uso esistono traduzioni. Serve solo a scriverlo
-- nel log: un'interfaccia che resta italiana senza che l'utente l'abbia
-- chiesta è un sintomo da poter diagnosticare.
function Settings.hasStrings()
    local lang = Settings.lang()
    if lang == DEFAULT_LANG then return true end
    return (STRINGS ~= nil) and (STRINGS[lang] ~= nil)
end

-- Le etichette già risolte, da spedire a chi non è scritto in Lua.
-- Il generatore Excel è in Python e deve scrivere testo tradotto: invece di
-- tenere una seconda copia delle tabelle là dentro — la stessa regola in due
-- posti, che è il difetto che ha prodotto lo scarto fra foglio e motore del
-- 30 ottobre — riceve le corrispondenze già fatte dentro il JSON di export.
function Settings.labelMaps()
    local function mapFor(group, values)
        local t = {}
        for _, v in ipairs(values) do t[v] = labelOf(group, v) end
        return t
    end
    return {
        language  = Settings.lang(),
        models    = mapFor("models",    Settings.MODELS),
        media     = mapFor("media",     Settings.MEDIA_TYPES),
        discounts = mapFor("discounts", Settings.DISCOUNT_TYPES),
    }
end

-- Il simbolo da solo. Per le etichette: "Tariffa (" .. cur() .. "):"
function Settings.cur()
    return Settings.load().symbol
end

function Settings.code()
    return Settings.load().code
end

-- Importo completo di simbolo. Per le frasi: "→ " .. money(696)
-- Nessuna conversione: il numero è quello che arriva.
function Settings.money(n)
    if type(n) ~= "number" then return tostring(n) end
    return Settings.cur() .. string.format("%.2f", n)
end

-- Variante con spazio, per i totali in evidenza: "TOTALE: € 1234.56"
function Settings.moneySpaced(n)
    if type(n) ~= "number" then return tostring(n) end
    return Settings.cur() .. " " .. string.format("%.2f", n)
end

-- Svuota la cache: serve al Config dopo un cambio di valuta, perché le
-- finestre già aperte rileggano il nuovo simbolo.
function Settings.reload()
    cache = nil
    return Settings.load()
end

return Settings
