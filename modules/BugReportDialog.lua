-- ==============================================================
-- BugReportDialog.lua — Dialog di segnalazione bug con Privacy Notice
-- Per: RepertoireDB_Config.lua, Calculator.lua, Monitor.lua
-- ==============================================================

local BugReportDialog = {}

-- Configurazione
BugReportDialog.RECIPIENT = "tomfilmeditor.tools@gmail.com"
BugReportDialog.PAYPAL_LINK = "https://paypal.me/acoffeefortom"

-- Rileva versione DaVinci Resolve
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

-- Rileva informazioni di sistema
local function getSystemInfo()
    local os_name = jit.os or "Unknown"
    local resolve_version = getResolveVersion()

    return {
        os = os_name,
        resolve_version = resolve_version,
        lua_version = _VERSION or "5.3"
    }
end

-- Crea il testo della privacy notice
local function createPrivacyNotice()
    return [[
⚠️  PRIVACY NOTICE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Questo report contiene:
  ✓ Versione OS e DaVinci Resolve
  ✓ Versione dello script
  ✓ Nomi dei tuoi timeline
  ✓ Timestamp delle operazioni
  ✓ Costi calcolati (se applicabile)

Questo report NON contiene:
  ✗ Password o credenziali
  ✗ API key o token
  ✗ Indirizzi IP
  ✗ Dettagli finanziari personali

Inviando il report, autorizzi Tom a usare questi dati
SOLO per diagnosticare il bug segnalato.

Se ci sono informazioni sensibili, puoi editarle
nell'email prima di inviare.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]
end

-- Template email pre-compilato per il bug report
function BugReportDialog:createEmailTemplate(scriptName, scriptVersion)
    local sysInfo = getSystemInfo()
    
    -- Costruisci l'oggetto dell'email
    local emailSubject = string.format(
        "Segnalazione Bug %s v%s | %s | Resolve %s",
        scriptName,
        scriptVersion,
        sysInfo.os,
        sysInfo.resolve_version
    )
    
    -- Corpo dell'email con privacy notice
    local emailBody = string.format(
        [[Script          : %s v%s
OS              : %s
DaVinci Resolve : %s
Data/Ora        : %s

--- Descrizione del problema ---
[Descrivi qui quello che è accaduto]

--- Comportamento atteso ---
[Descrivi come dovrebbe funzionare]

--- Step per riprodurre il problema ---
1. [primo step]
2. [secondo step]
3. [terzo step]

--- Log o screenshot ---
[Se disponibile, allega qui il file di log]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Grazie per il bug report! Se puoi supportare lo sviluppo:
%s

⚠️  Privacy: questo report contiene OS, timeline, costi.
    Non contiene password o API key. Vedi il notice sopra.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ]],
        scriptName,
        scriptVersion,
        sysInfo.os,
        sysInfo.resolve_version,
        os.date("%Y-%m-%d %H:%M:%S"),
        self.PAYPAL_LINK
    )
    
    return {
        subject = emailSubject,
        body = emailBody,
        recipient = self.RECIPIENT
    }
end

-- Mostra il dialog con privacy notice e bottoni
function BugReportDialog:show(scriptName, scriptVersion)
    -- Crea finestra dialog
    local dialog = nil
    
    -- Tenta di usare Fusion UI se disponibile, altrimenti fallback a OS dialog
    local useNativeDialog = pcall(function()
        -- Se sei in DaVinci Resolve, usa il dialog nativo di Fusion
        dialog = fu.RequestDir(true, "")
    end)
    
    -- Costruisci il messaggio completo
    local privacyNotice = createPrivacyNotice()
    local emailTemplate = self:createEmailTemplate(scriptName, scriptVersion)
    
    -- Stampa il notice e le istruzioni (fallback se UI non disponibile)
    print(privacyNotice)
    print("\n📧 EMAIL PRE-COMPILATA PRONTA")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("\nOggetto: " .. emailTemplate.subject)
    print("\nDestinario: " .. emailTemplate.recipient)
    print("\nCopia il testo qui sotto e incollalo nella tua email:\n")
    print(emailTemplate.body)
    
    return emailTemplate
end

-- Apri l'email client con il template pre-compilato (macOS)
function BugReportDialog:sendEmail(scriptName, scriptVersion)
    local emailTemplate = self:createEmailTemplate(scriptName, scriptVersion)
    
    -- Escape speciali per terminale
    local subject = emailTemplate.subject:gsub('"', '\\"')
    local body = emailTemplate.body:gsub('"', '\\"'):gsub('\n', '\\n')
    
    -- Comando AppleScript per aprire Mail.app con il template
    local applescript = string.format(
        [[
tell application "Mail"
    activate
    set newMessage to make new outgoing message with properties {subject:"%s", content:"%s", visible:true}
    tell newMessage
        make new to recipient at end of to recipients with properties {address:"%s"}
    end tell
end tell
        ]],
        subject,
        body,
        emailTemplate.recipient
    )
    
    -- Esegui lo script
    os.execute('osascript -e \'' .. applescript .. '\'')
end

-- Bottone "Segnala Bug" da inserire negli script
function BugReportDialog:createButton(scriptName, scriptVersion)
    return {
        label = "🐛 Segnala Bug",
        action = function()
            -- Mostra privacy notice e template
            self:show(scriptName, scriptVersion)
            
            -- Tenta di aprire l'email client
            local success = pcall(function()
                self:sendEmail(scriptName, scriptVersion)
            end)
            
            if not success then
                print("❌ Impossibile aprire il client email.")
                print("Copia il template sopra e invia manualmente a: " .. self.RECIPIENT)
            end
        end
    }
end

return BugReportDialog
