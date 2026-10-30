#!/bin/bash
# ============================================================
# build_installer.sh — Genera gli installer RepertoireDB
# Produce due file autoscompattanti (macOS .command + Windows .cmd)
# a partire dai file reali installati in DaVinci Resolve.
#
# Uso:
#   ./build_installer.sh                  → versione letta dagli script, senza database
#   ./build_installer.sh --with-db        → include anche repertoire_db.json
#   ./build_installer.sh --version 1.3.0  → forza un numero di versione
#
# Autore: Tommaso Feraboli — Film Editor
# ============================================================

set -euo pipefail

SRC_SCRIPTS="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB"
SRC_MODULES="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Modules/Lua"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"

INCLUDE_DB="no"
VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --with-db)  INCLUDE_DB="yes"; shift ;;
        --version)  VERSION="$2"; shift 2 ;;
        *) echo "Opzione sconosciuta: $1"; exit 1 ;;
    esac
done

# ── Versione: letta da Config.lua se non forzata ─────────────────────────
if [ -z "$VERSION" ]; then
    VERSION=$(grep -m1 '^local VERSION' "$SRC_SCRIPTS/RepertoireDB_Config.lua" | sed 's/.*"\(.*\)".*/\1/')
fi
[ -n "$VERSION" ] || { echo "ERRORE: versione non rilevata"; exit 1; }

echo "== Generazione installer RepertoireDB v$VERSION =="
echo "   database incluso: $INCLUDE_DB"
echo ""

# ── Coerenza versioni fra i tre script ──────────────────────────────────
for f in RepertoireDB_Config.lua RepertoireDB_Calculator.lua RepertoireDB_Monitor.lua; do
    v=$(grep -m1 -E '^local (SCRIPT_)?VERSION' "$SRC_SCRIPTS/$f" | sed 's/.*"\(.*\)".*/\1/')
    if [ "$v" != "$VERSION" ]; then
        echo "ERRORE: $f dichiara v$v, atteso v$VERSION."
        echo "        Allinea le versioni prima di generare il pacchetto."
        exit 1
    fi
done
echo "Versioni allineate nei tre script: OK"

# ── Traduzioni complete ─────────────────────────────────────────────────
# Ogni testo mostrato all'utente passa per T("..."): se una di quelle frasi
# non ha traduzione, chi usa l'interfaccia in inglese vede una riga italiana
# in mezzo. Non è un errore che si nota generando il pacchetto, quindi la
# build si ferma.
TOOLS_TRAD="$(cd "$(dirname "$0")/../../tools-traduzione" 2>/dev/null && pwd)"
if [ -n "$TOOLS_TRAD" ] && [ -f "$TOOLS_TRAD/verifica_traduzioni.py" ]; then
    if ! python3 -I "$TOOLS_TRAD/verifica_traduzioni.py" > /tmp/rdb_trad.log 2>&1; then
        echo "ERRORE: le traduzioni non sono complete o coerenti."
        sed 's/^/        /' /tmp/rdb_trad.log
        echo "        Correggi tools-traduzione/traduzioni_en.py e rigenera con genera_en.py."
        exit 1
    fi
    echo "Traduzioni complete e coerenti: OK"
else
    echo "ATTENZIONE: verifica_traduzioni.py non trovato, controllo saltato."
fi

# Il modulo delle traduzioni deve esistere e contenere qualcosa
if [ ! -s "$SRC_MODULES/Strings.lua" ]; then
    echo "ERRORE: $SRC_MODULES/Strings.lua manca o è vuoto."
    echo "        Generalo con tools-traduzione/genera_en.py e copialo nei moduli."
    exit 1
fi

# ── Staging ─────────────────────────────────────────────────────────────
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/payload/RepertoireDB/Templates" "$STAGE/payload/Modules_Lua"

# Script eseguibili + documentazione (vanno in Fusion/Scripts/Comp/RepertoireDB/)
for f in RepertoireDB_Config.lua RepertoireDB_Calculator.lua RepertoireDB_Monitor.lua \
         RepertoireDB_Installer.lua RepertoireDB_xlsx.py RepertoireDB_README.txt \
         CHANGELOG.md LICENSE.md; do
    cp "$SRC_SCRIPTS/$f" "$STAGE/payload/RepertoireDB/"
done
# Templates: TUTTI tranne RepertoireDB_Archivi.csv, che contiene le tariffe
# reali negoziate (12 archivi + note commerciali). Al suo posto va il template
# con le tariffe a zero, che vive accanto a questo generatore.
for t in "$SRC_SCRIPTS"/Templates/*.csv; do
    case "$(basename "$t")" in
        RepertoireDB_Archivi.csv)
            echo "  escluso dal pacchetto (contiene il listino): $(basename "$t")" ;;
        *)
            cp "$t" "$STAGE/payload/RepertoireDB/Templates/" ;;
    esac
done

if [ -f "$OUT_DIR/RepertoireDB_Archivi_template.csv" ]; then
    cp "$OUT_DIR/RepertoireDB_Archivi_template.csv" "$STAGE/payload/RepertoireDB/Templates/"
else
    echo "ERRORE: manca RepertoireDB_Archivi_template.csv accanto al generatore."
    echo "       Senza quello il pacchetto resterebbe senza elenco archivi."
    exit 1
fi

# Rete di sicurezza: nessuna tariffa reale deve entrare nel pacchetto.
if grep -rqE "Istituto Luce,[A-Za-z ]+,[1-9]|Reuters,[A-Za-z ]+,[1-9]|RAI COM,[A-Za-z ]+,[1-9]" "$STAGE/payload" 2>/dev/null; then
    echo "ERRORE: trovata una tariffa reale nel pacchetto. Generazione annullata."
    grep -rlE "Istituto Luce,[A-Za-z ]+,[1-9]" "$STAGE/payload" | sed 's/^/       /'
    exit 1
fi

# Istruzioni di installazione bilingui (vivono accanto al generatore,
# non nella cartella degli script)
if [ -f "$OUT_DIR/INSTALL.txt" ]; then
    cp "$OUT_DIR/INSTALL.txt" "$STAGE/payload/RepertoireDB/"
else
    echo "ATTENZIONE: INSTALL.txt non trovato in $OUT_DIR — pacchetto senza istruzioni"
fi

# Database banche dati: solo se richiesto esplicitamente
if [ "$INCLUDE_DB" = "yes" ]; then
    cp "$SRC_SCRIPTS/repertoire_db.json" "$STAGE/payload/RepertoireDB/repertoire_db.json.default"
fi

# Moduli condivisi (vanno in Fusion/Modules/Lua/ — cartella DIVERSA)
for f in LogManager.lua BugReportDialog.lua Settings.lua Strings.lua; do
    cp "$SRC_MODULES/$f" "$STAGE/payload/Modules_Lua/"
done

# Pulizia file di sistema macOS
find "$STAGE/payload" -name '.DS_Store' -delete

echo "File nel pacchetto:"
find "$STAGE/payload" -type f | sed "s|$STAGE/payload/|  |" | sort

# ── Archivio ────────────────────────────────────────────────────────────
TARBALL="$STAGE/payload.tar.gz"
tar -czf "$TARBALL" -C "$STAGE/payload" --exclude='.DS_Store' RepertoireDB Modules_Lua
B64=$(base64 < "$TARBALL" | tr -d '\n')

cp "$TARBALL" "$OUT_DIR/RepertoireDB_${VERSION}.tar.gz"

# ── Installer macOS ─────────────────────────────────────────────────────
MAC_OUT="$OUT_DIR/RepertoireDB_${VERSION}_Install_macOS.command"
{
cat <<'MACHEAD'
#!/bin/bash
# RepertoireDB — Installer macOS
set -e

FUSION="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion"
DEST_SCRIPTS="$FUSION/Scripts/Comp/RepertoireDB"
DEST_MODULES="$FUSION/Modules/Lua"

echo ""
echo "== Installazione RepertoireDB =="
echo ""

mkdir -p "$DEST_SCRIPTS" "$DEST_MODULES"

TEMP_DIR=$(mktemp -d)
TEMP_TAR="$TEMP_DIR/payload.tar.gz"
MACHEAD

printf "echo '%s' | base64 -D > \"\$TEMP_TAR\"\n" "$B64"

cat <<'MACFOOT'
tar -xzf "$TEMP_TAR" -C "$TEMP_DIR"

# 1) Script e documentazione
cp -R "$TEMP_DIR/RepertoireDB/." "$DEST_SCRIPTS/"
echo "Script installati in:"
echo "  $DEST_SCRIPTS"

# 2) Moduli condivisi — cartella diversa, senza questi gli script non partono
cp "$TEMP_DIR/Modules_Lua/"*.lua "$DEST_MODULES/"
echo "Moduli installati in:"
echo "  $DEST_MODULES"

# 3) Database banche dati: creato solo alla prima installazione,
#    mai sovrascritto se esiste gia' (contiene i dati dell'utente)
if [ -f "$DEST_SCRIPTS/repertoire_db.json.default" ]; then
    if [ -f "$DEST_SCRIPTS/repertoire_db.json" ]; then
        rm "$DEST_SCRIPTS/repertoire_db.json.default"
        echo "Database gia' presente: lasciato intatto."
    else
        mv "$DEST_SCRIPTS/repertoire_db.json.default" "$DEST_SCRIPTS/repertoire_db.json"
        echo "Database di partenza installato."
    fi
fi

rm -rf "$TEMP_DIR"

echo ""
echo "Fatto. Avvia da DaVinci Resolve:"
echo "  Workspace > Scripts > Comp > RepertoireDB_Config"
echo ""
echo "Nota: l'interfaccia degli script richiede DaVinci Resolve Studio"
echo "      (dalla 19.1 l'interfaccia grafica non e' piu' disponibile"
echo "       nella versione gratuita)."
echo ""
read -p "Premi INVIO per chiudere..." _ || true
MACFOOT
} > "$MAC_OUT"
chmod +x "$MAC_OUT"

# ── Installer Windows ───────────────────────────────────────────────────
WIN_OUT="$OUT_DIR/RepertoireDB_${VERSION}_Install_Windows.cmd"
{
cat <<'WINHEAD'
@echo off
REM RepertoireDB - Installer Windows
setlocal enabledelayedexpansion

set "FUSION=%APPDATA%\Blackmagic Design\DaVinci Resolve\Fusion"
set "DEST_SCRIPTS=%FUSION%\Scripts\Comp\RepertoireDB"
set "DEST_MODULES=%FUSION%\Modules\Lua"

echo.
echo == Installazione RepertoireDB ==
echo.

if not exist "!DEST_SCRIPTS!" mkdir "!DEST_SCRIPTS!"
if not exist "!DEST_MODULES!" mkdir "!DEST_MODULES!"

set "TMPDIR=%TEMP%\rdb_install"
if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
mkdir "!TMPDIR!"

WINHEAD

printf 'powershell -Command "$b64='"'"'%s'"'"'; $bytes=[System.Convert]::FromBase64String($b64); [System.IO.File]::WriteAllBytes('"'"'!TMPDIR!\\payload.tar.gz'"'"',$bytes)"\n' "$B64"

cat <<'WINFOOT'
powershell -Command "cd '!TMPDIR!'; tar -xzf payload.tar.gz"

REM 1) Script e documentazione
xcopy /E /I /Y /Q "!TMPDIR!\RepertoireDB" "!DEST_SCRIPTS!" >nul
echo Script installati in:
echo   !DEST_SCRIPTS!

REM 2) Moduli condivisi - cartella diversa, senza questi gli script non partono
copy /Y "!TMPDIR!\Modules_Lua\*.lua" "!DEST_MODULES!" >nul
echo Moduli installati in:
echo   !DEST_MODULES!

REM 3) Database banche dati: mai sovrascritto se esiste gia'
if exist "!DEST_SCRIPTS!\repertoire_db.json.default" (
    if exist "!DEST_SCRIPTS!\repertoire_db.json" (
        del /q "!DEST_SCRIPTS!\repertoire_db.json.default"
        echo Database gia' presente: lasciato intatto.
    ) else (
        ren "!DEST_SCRIPTS!\repertoire_db.json.default" repertoire_db.json
        echo Database di partenza installato.
    )
)

rmdir /s /q "!TMPDIR!"

echo.
echo Fatto. Avvia da DaVinci Resolve:
echo   Workspace ^> Scripts ^> Comp ^> RepertoireDB_Config
echo.
echo Nota: l'interfaccia degli script richiede DaVinci Resolve Studio
echo       (dalla 19.1 l'interfaccia grafica non e' piu' disponibile
echo        nella versione gratuita).
echo.
pause
WINFOOT
} > "$WIN_OUT"

# ── Lo .command va distribuito DENTRO UNO ZIP ───────────────────────────
# Un download HTTP non trasporta i permessi Unix: il file parte eseguibile
# e arriva -rw-r--r--, quindi il doppio clic risponde "you do not have
# appropriate access privileges" a CHIUNQUE lo scarichi. Dentro uno zip il
# permesso viaggia con l'archivio e sopravvive allo scompattamento.
# Difetto reale: la Release v1.2.14 è rimasta inutilizzabile per giorni.
# Windows non è colpito: i .cmd si eseguono per estensione, senza bit.
MAC_ZIP="$OUT_DIR/RepertoireDB_${VERSION}_Install_macOS.command.zip"
rm -f "$MAC_ZIP"
( cd "$OUT_DIR" && zip -q "$(basename "$MAC_ZIP")" "$(basename "$MAC_OUT")" )

# La build si ferma se il bit non sopravvive: meglio nessun pacchetto che
# un pacchetto che non si avvia.
VERIFICA=$(mktemp -d)
( cd "$VERIFICA" && unzip -q "$MAC_ZIP" )
if [ -x "$VERIFICA/$(basename "$MAC_OUT")" ]; then
    echo "Zip macOS: il bit di esecuzione sopravvive allo scompattamento — OK"
else
    echo "ERRORE: nello zip il file non risulta eseguibile. Non distribuirlo."
    rm -rf "$VERIFICA"; exit 1
fi
rm -rf "$VERIFICA"

echo ""
echo "Generati:"
ls -lh "$MAC_ZIP" "$WIN_OUT" "$OUT_DIR/RepertoireDB_${VERSION}.tar.gz" | awk '{print "  " $9 "  (" $5 ")"}'
echo ""
echo "Da allegare alla Release: SOLO lo zip macOS e il .cmd Windows."
echo "Lo .command nudo resta qui per i test locali, non va distribuito."
echo ""
