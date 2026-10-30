-- ==============================================================
-- Settings.lua — Impostazioni condivise fra gli script RepertoireDB
-- (Lua 5.1, come il Lua incorporato in DaVinci Resolve)
--
-- Oggi contiene solo la valuta. È un modulo a sé perché i tre script
-- leggono la configurazione ognuno per conto proprio, e serviva un
-- punto comune: lo stesso schema di LogManager e BugReportDialog.
--
-- Il file delle impostazioni è separato da repertoire_db.json, che
-- resta una lista di banche dati: così i database già esistenti non
-- vengono toccati, e se il file manca si assume l'euro.
--
-- Autore: Tommaso Feraboli — Film Editor
-- Licenza MIT
-- ==============================================================

local Settings = {}

local DEFAULT_SYMBOL = "€"
local DEFAULT_CODE   = "EUR"

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
    cache = { symbol = DEFAULT_SYMBOL, code = DEFAULT_CODE }

    local f = io.open(Settings.getPath(), "r")
    if not f then return cache end          -- file assente: euro
    local txt = f:read("*a") or ""
    f:close()

    local sym = txt:match('"currency_symbol"%s*:%s*"([^"]*)"')
    local cod = txt:match('"currency_code"%s*:%s*"([^"]*)"')
    if sym and sym ~= "" then cache.symbol = sym end
    if cod and cod ~= "" then cache.code   = cod end
    return cache
end

function Settings.save(symbol, code)
    cache = { symbol = symbol or DEFAULT_SYMBOL, code = code or DEFAULT_CODE }
    local path = Settings.getPath()

    -- La directory potrebbe non esistere alla primissima installazione
    local sep = package.config:sub(1,1)
    if sep ~= "\\" then
        os.execute('mkdir -p "' .. path:gsub("/[^/]*$", "") .. '"')
    end

    local f = io.open(path, "w")
    if not f then return false, "Impossibile scrivere: " .. path end
    f:write(string.format(
        '{\n  "currency_symbol": "%s",\n  "currency_code": "%s"\n}\n',
        cache.symbol, cache.code))
    f:close()
    return true
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
