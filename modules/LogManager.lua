-- ==============================================================
-- LogManager.lua — Sistema centralizzato di logging (Lua 5.1 compatible)
-- Compatibile con: RepertoireDB_Calculator, Config, Monitor
-- ==============================================================

local LogManager = {}

-- Configurazione
LogManager.LOG_DIR = os.getenv("HOME") .. "/Library/Logs/RepertoireDB"
LogManager.LOG_FILE = LogManager.LOG_DIR .. "/repertoire_db.log"
LogManager.MAX_LOG_SIZE = 5 * 1024 * 1024  -- 5 MB prima di rotazione
LogManager.LEVELS = {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    CRITICAL = 4
}
LogManager.MIN_LEVEL = LogManager.LEVELS.INFO  -- Cambiare a DEBUG per debug completo

-- Inizializzazione
function LogManager:init()
    -- Crea directory se non esiste
    os.execute("mkdir -p '" .. LogManager.LOG_DIR .. "'")
end

-- Crea timestamp nel formato ISO
local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Formatta messaggio di log
local function formatLogMessage(level, script, message)
    return string.format("[%s] [%s] %s: %s",
        getTimestamp(),
        level,
        script,
        message
    )
end

-- Controlla se serve rotazione del log (versione semplice per Lua 5.1)
local function needsRotation()
    local f = io.open(LogManager.LOG_FILE, "r")
    if not f then return false end

    -- Conta le linee come fallback (meno efficiente ma Lua 5.1 compatible)
    local linecount = 0
    for _ in f:lines() do
        linecount = linecount + 1
    end
    f:close()

    -- Se > 100k linee approssimativamente = 5 MB
    return linecount > 100000
end

-- Ruota il log (rinomina a .old)
local function rotateLog()
    if needsRotation() then
        local old_file = LogManager.LOG_FILE .. ".old"
        os.remove(old_file)  -- Cancella versione precedente
        os.rename(LogManager.LOG_FILE, old_file)
    end
end

-- Scrive sul file di log
local function writeToFile(message)
    rotateLog()
    local f = io.open(LogManager.LOG_FILE, "a")
    if f then
        f:write(message .. "\n")
        f:close()
        return true
    end
    return false
end

-- Funzione principale di logging
function LogManager:log(level, script, message, data)
    -- Controlla livello minimo
    if LogManager.LEVELS[level] < LogManager.MIN_LEVEL then
        return
    end

    -- Costruisci messaggio
    local formatted = formatLogMessage(level, script, message)

    -- Aggiungi dati strutturati se presenti (per errori/debug)
    if data then
        formatted = formatted .. " | " .. self:serializeData(data)
    end

    -- Scrivi su file
    local success = writeToFile(formatted)

    -- Su CRITICAL, prova anche a scrivere in stderr
    if level == "CRITICAL" and not success then
        io.stderr:write(formatted .. "\n")
    end
end

-- Serializza dati per il log (tabelle Lua → stringa)
function LogManager:serializeData(data)
    if type(data) == "string" then
        return data
    elseif type(data) == "table" then
        local parts = {}
        for k, v in pairs(data) do
            table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(data)
    end
end

-- Utility functions con firma breve
function LogManager:debug(script, message, data)
    self:log("DEBUG", script, message, data)
end

function LogManager:info(script, message, data)
    self:log("INFO", script, message, data)
end

function LogManager:warn(script, message, data)
    self:log("WARNING", script, message, data)
end

function LogManager:error(script, message, data)
    self:log("ERROR", script, message, data)
end

function LogManager:critical(script, message, data)
    self:log("CRITICAL", script, message, data)
end

-- Leggi ultimi N righe dal log (per debugging)
function LogManager:getTail(n)
    n = n or 20
    local lines = {}
    local f = io.open(LogManager.LOG_FILE, "r")

    if not f then return {} end

    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()

    -- Estrai ultimi N
    local start = math.max(1, #lines - n + 1)
    local result = {}
    for i = start, #lines do
        table.insert(result, lines[i])
    end

    return result
end

-- Leggi intero log
function LogManager:readAll()
    local f = io.open(LogManager.LOG_FILE, "r")
    if not f then return "" end
    local content = f:read("*a")
    f:close()
    return content
end

return LogManager
