# RepertoireDB — Changelog

## [1.4.0] — 2026-10-30

### Interfaccia in inglese, con rilevazione automatica dalla lingua di sistema

Lo strumento era in italiano da sempre. Ora l'interfaccia dei tre script è
disponibile anche in inglese, e la lingua si sceglie da un menu nel Config:
`Automatico`, `Italiano`, `English`.

**L'automatico segue la lingua del SISTEMA OPERATIVO, non quella di DaVinci
Resolve.** Sono due impostazioni diverse: si può avere Resolve in inglese su un
Mac in italiano, o il contrario. Quella che conta è la lingua del sistema,
perché è quella che l'utente ha scelto per leggere. La voce del menu dice fra
parentesi su cosa è caduta la rilevazione, così non è una scatola chiusa.

Rilevata da `AppleLanguages` su macOS (l'ordine delle lingue dell'interfaccia,
non `AppleLocale`, che è il formato di numeri e date e può essere diverso), da
`Get-UICulture` su Windows con il registro come ripiego, dalle variabili
`LANG`/`LC_ALL`/`LC_MESSAGES` su Linux. Su macOS le variabili d'ambiente non
bastano: le applicazioni con interfaccia grafica non ereditano `LANG`.

Una lingua di sistema che lo strumento non conosce ricade sull'italiano.
L'interfaccia non resta mai vuota.

**Tradotto anche il foglio Excel esportato**: intestazioni, note, legenda e i
nomi dei tre fogli (`Summary` / `Segments` / `Config`). I nomi dei fogli stanno
dentro ogni formula, quindi tradurli ha richiesto di tradurli anche là: testo e
formule escono dalla stessa tabella nella stessa esecuzione, e il collaudo è
che il totale del foglio inglese deve coincidere con quello dell'italiano.

**Il CSV del preventivo** viene tradotto, perché è un report da leggere.
**L'esportazione CSV del Config no**, perché è reimportabile: un file esportato
deve rientrare nello strumento di chiunque, in qualunque lingua lo usi.

**Nuovo modulo `Strings.lua`** in `Fusion/Modules/Lua/`. È **facoltativo**: se
manca, o è di una versione più vecchia, l'interfaccia resta in italiano senza
dare errore a schermo. L'italiano è scritto nel codice e non in quel file,
proprio perché senza di esso non resterebbe niente da mostrare.

### Corretti i plurali

Erano costruiti attaccando una lettera alla parola: `"second" .. "o"/"i"`.
Funziona in italiano e in nessun'altra lingua. Ora sono frasi complete e
separate, una per il singolare e una per il plurale, così ogni lingua
pluralizza a modo suo.

### Separazione fra valori salvati ed etichette mostrate

**Il campo `model` di ogni banca dati conteneva `"A clip"`, `"Al minuto"`: la
stessa stringa faceva da valore salvato nel file e da etichetta mostrata a
schermo.** Tradurre l'interfaccia così com'era avrebbe riscritto il contenuto
dei database.

Il campo `model` di ogni banca dati conteneva `"A clip"`, `"Al minuto"` e
compagnia: la stessa stringa faceva da valore salvato nel file **e** da
etichetta mostrata a schermo. Tradurre l'interfaccia così com'era avrebbe
riscritto il contenuto dei database.

**Decisione presa (30 ottobre 2026): il valore salvato resta la stringa
italiana, per sempre.** Non è un residuo da correggere: è il contenuto del campo
`model` e `mediaType` in `repertoire_db.json`, delle configurazioni in
`memories/`, e della colonna `Model` nei CSV di importazione — che è un formato
pubblico, documentato nel manuale e già distribuito con la 1.3.0. Cambiarlo
avrebbe richiesto di migrare i database reali, riscrivere i template e tenere
per sempre un lettore che accetta entrambe le forme: tre punti dove si può
sbagliare in silenzio su dati di produzione, in cambio di un vantaggio che
l'utente non vede mai.

Quello che si traduce sono le **etichette**, in `Settings.lua`.

- `Settings.lua` ora contiene, oltre alla valuta: la lingua dell'interfaccia
  (`it`/`en`, salvata in `repertoire_settings.json`), i valori di dominio in un
  posto solo (`MODELS`, `MEDIA_TYPES`, `DISCOUNT_TYPES`), nomi simbolici per non
  ripetere le stringhe nel codice (`Settings.MODEL.CLIP` e simili), e le tabelle
  delle etichette per lingua.
- Nessun quarto modulo condiviso: la lingua è un'impostazione come la valuta, e
  `Settings.lua` è già installato dalla 1.3.0. Un modulo nuovo avrebbe richiesto
  di rifare installer e istruzioni il giorno dopo averli pubblicati.
- Un valore che non è in tabella viene mostrato così com'è, e una lingua
  sconosciuta ricade sull'italiano: in nessun caso l'interfaccia resta vuota.
- La scrittura di `repertoire_settings.json` è ora in un punto solo. Prima
  `Settings.save` riscriveva il file da zero con le sole chiavi della valuta:
  aggiungendo la lingua, salvare la valuta l'avrebbe cancellata.

**Config.lua** — tutti i letterali sostituiti: i menu mostrano le etichette
nell'ordine dei valori (così l'indice scelto resta l'indice del valore da
salvare), l'elenco banche mostra modello e tipo tradotti, la ricerca trova sia
il valore salvato sia l'etichetta mostrata (con l'interfaccia in inglese si
cerca "Photos" ma nel database c'è "Fotografie"), e l'importazione CSV accetta
sia il valore canonico sia l'etichetta tradotta.

**L'esportazione CSV del Config resta canonica**, perché è reimportabile: un
file esportato deve poter rientrare nello strumento di chiunque, in qualunque
lingua lo usi.

**Calculator.lua** — sostituiti tutti e 46 i letterali. I confronti che decidono
quale formula di prezzo si applica usano ora le costanti; le intestazioni di
categoria, la colonna Modello nell'albero dei risultati e il CSV del preventivo
mostrano le etichette tradotte. **Il JSON per il generatore Excel resta
canonico**: i valori li traduce chi scrive il foglio, non chi li trasmette.

Verificato rimettendo i letterali al posto delle costanti e confrontando col
file archiviato: le differenze sono soltanto la versione, due costruzioni di
tabella e sei punti di visualizzazione. **Nessun confronto di prezzo è
cambiato.**

**Monitor.lua** — cinque letterali sostituiti, `Settings` aggiunto fra i moduli
caricati, intestazioni di categoria tradotte.

**RepertoireDB_xlsx.py** — il generatore è in Python e deve scrivere testo
tradotto, ma **non tiene una seconda tabella di traduzioni**: riceve le
corrispondenze già risolte dentro il JSON, in `labels`. La stessa regola in due
posti è quello che ha prodotto lo scarto fra foglio e motore corretto in questa
stessa versione.

Il punto delicato: i letterali dentro le formule (`VLOOKUP(...)="Al secondo"`)
confrontano quello che è **scritto nel foglio**. Testo delle celle e letterali
delle formule escono adesso dalla stessa tabella, nella stessa esecuzione,
quindi sono coerenti per costruzione. Un JSON prodotto da un Calculator più
vecchio, senza `labels`, continua a funzionare come prima.

Provato generando lo stesso preventivo nelle due lingue, con tutte e tre le
categorie e con uno sconto a soglia attivo: **totali identici** (8325 contro
8325, e sconto 10% su 35 che dà 31,50 in entrambe), zero errori di formula al
ricalcolo, e il foglio inglese che mostra `Per clip`, `Flat fee`, `Per second`,
`Photos`, `NEWSPAPERS`.

### Menu Lingua nel Config, con rilevazione automatica dal sistema operativo

Nel Config, in alto, un menu **Lingua** accanto a quello della valuta. Tre voci:
`Automatico — <lingua rilevata>`, `Italiano`, `English`. La voce automatica dice
su cosa è caduta la rilevazione, così non è una scatola chiusa.

**La rilevazione guarda la lingua del SISTEMA OPERATIVO, non quella di DaVinci
Resolve.** Sono due impostazioni diverse: si può avere Resolve in inglese su un
Mac in italiano, o il contrario. Quella che conta è la lingua del sistema,
perché è quella che l'utente ha scelto per leggere.

Come viene rilevata:

| Sistema | Come |
|---|---|
| macOS | `AppleLanguages`, che è l'ordine delle lingue dell'**interfaccia**. Non `AppleLocale`, che è il formato di numeri e date e può essere diverso: un Mac in inglese con formati italiani è una configurazione comune |
| Windows | `Get-UICulture` via PowerShell; se non risponde, la chiave `LocaleName` del registro |
| Linux | `LANG`, `LC_ALL`, `LC_MESSAGES` |

Su macOS le variabili d'ambiente **non** bastano: le applicazioni con interfaccia
grafica non ereditano `LANG`, che su questa macchina risulta non impostata.

Una lingua di sistema che non sappiamo tradurre, o un comando che non risponde,
ricadono sull'italiano: in nessun caso l'interfaccia resta vuota.

Cambiando lingua, i menu dei modelli, dei tipi di media e dei tipi di sconto, e
l'elenco delle banche dati, vengono ricostruiti subito: non serve riaprire la
finestra.

**Difetto corretto durante questo lavoro**: `Settings.save` riscriveva il file
delle impostazioni con le sole chiavi della valuta. Con l'aggiunta della lingua,
salvare la valuta l'avrebbe cancellata e viceversa. Ora la scrittura è in un
punto solo e il comportamento è verificato nei due versi.

Da fare: le ~190 stringhe di interfaccia. **Finché non sono tradotte, scegliere
English — o avere un sistema in inglese — produce un'interfaccia mista: etichette
dei modelli in inglese e tutto il resto in italiano.** È lo stato atteso di una
versione `-dev` e non va distribuito così.

## [1.3.0] — 2026-10-30

### Corretto — il foglio Excel fatturava il materiale riusato

**Il difetto più importante di questa versione, presente in tutte le precedenti.**

Il foglio Excel ricontava le clip e le durate con formule proprie, e non sapeva
riconoscere il materiale già conteggiato. Risultato: se gli stessi fotogrammi
sorgente comparivano più volte nel montaggio, il foglio li fatturava più volte,
mentre il Calculator li fattura una sola. Su una timeline reale il foglio dava
**64530** dove il motore dava **64460**; su una banca a modello "A clip" contava
**42 clip invece di 6**, e lì il danno era invisibile solo perché la tariffa era
ancora da compilare. **Il CSV non era toccato**: porta i numeri del motore.

Tre cause distinte, tutte chiuse:

- Le durate sommavano la durata **totale** di ogni segmento invece dei
  fotogrammi non già conteggiati. Il Calculator quel dato lo calcolava ma non lo
  trasmetteva: ora sì.
- Il conteggio delle clip includeva le comparse successive della stessa clip
  sorgente, che per il modello "A clip" si paga una volta.
- La riga di sottototale per banca veniva contata come se fosse una clip, perché
  porta il nome della banca nella colonna su cui il conteggio lavorava.

Il criterio applicato, nelle parole dell'autore: **a clip si paga una volta per
clip sorgente; a forfait una volta per banca, incluse tutte le sue clip; i
duplicati si mostrano ma non si contano mai, salvo il primo uso.**

Un segmento ripetuto solo **in parte** resta fatturato per la sua parte nuova, e
non viene contato fra le riusate.

### Aggiunto — colonna "Riusate" nel Riepilogo

Dice, per ogni banca, quante comparse non vengono fatturate perché il materiale
era già conteggiato. Con subtotale per categoria e totale generale. Serve a
vedere insieme le due cose che prima si potevano solo dedurre: quanto paghi e
quanto hai riusato.

### Modificato — il pulsante di esportazione dice cosa fa

Da `Esporta CSV` a **`Esporta CSV / XLSX`**. Il pulsante apre un dialogo che
offre entrambi i formati: il nome vecchio ne nascondeva metà.

### Da sapere — cosa si ricalcola nel foglio e cosa no

Il foglio Excel resta un foglio di calcolo vivo, ma non tutto quello che
contiene si ricalcola, e la distinzione ora è dichiarata nel manuale.

| | |
|---|---|
| **Si ricalcola** | tariffe, sconti e soglie, utilizzo minimo, durata del blocco — le condizioni commerciali, cioè i numeri su cui si tratta |
| **Non si ricalcola** | le durate fatturabili e quali comparse sono ripetizioni — sono misure prese leggendo il montaggio |

Il motivo è un limite reale del foglio di calcolo, non una scelta di comodo: per
sapere se gli stessi fotogrammi compaiono due volte servirebbe confrontare fra
loro gli intervalli di tutte le clip della stessa banca, tenendo conto delle
sovrapposizioni parziali. Una formula può sommare, non può riconoscere.

**Conseguenza pratica**: modificare a mano i timecode di un segmento nel foglio
non cambia il costo, e cancellare o aggiungere righe di segmento non produce un
conteggio coerente. Quando il montaggio cambia si rilancia il Calculator e si
riesporta. Il foglio serve a trattare sulle tariffe, non a correggere il
montaggio.

### Corretto — colonna "Secondi Scoperti" nel foglio Excel

Tre difetti nella stessa colonna, presenti anche nella 1.2.14 pubblicata. I primi
due trovati controllando il codice compilato, non leggendolo; il terzo è diventato
visibile solo dopo aver corretto gli altri.

- **I secondi usati e quelli scoperti non sommavano al minimo**: su un minimo di
  30 secondi si leggeva `Usati 16s - Scoperti 13s`, e chi faceva la sottrazione
  trovava 14 dove stava scritto 13. I due numeri venivano arrotondati per difetto
  ciascuno per conto suo (16,28 → 16 e 13,72 → 13). Ora si arrotonda il primo e
  il secondo si ricava per differenza.
- **"Usati" mostrava sempre 0.** La frase in colonna era `Min 60s - Usati 0s - Scoperti 15s`:
  il minimo e il deficit erano corretti, i secondi effettivamente usati no. La durata per
  banca veniva calcolata ma non arrivava mai alla funzione che scrive il JSON per l'Excel —
  non era fra i suoi parametri, quindi veniva letta come variabile globale inesistente, che
  in Lua vale `nil` senza produrre errore. **Il CSV non era toccato**: lì il numero è scritto
  nudo, senza la frase.
- **Intestazioni disallineate di una colonna.** Il titolo "Secondi Scoperti" stava sopra la
  colonna tecnica che contiene la somma dei frame, e il testo del deficit sotto il titolo
  "Note". Causa: la colonna tecnica non ha titolo, e l'elenco delle intestazioni era stato
  accorciato a otto voci quando le colonne scritte sono nove.

Corretto anche il riempimento dell'intestazione di categoria, che si fermava una colonna
prima del bordo della tabella.

### Aggiunto
- **Scelta della valuta.** Nel Config, in alto, un menu per scegliere la valuta con cui vengono mostrati gli importi: EUR €, USD $, GBP £, CHF, CAD CA$, AUD A$, CNY ¥, JPY ¥, KRW ₩.
  - **Cambia solo il simbolo mostrato. Nessuna conversione**: le cifre inserite restano quelle che sono. Un avviso lo dice a schermo nel momento del cambio, per non far pensare a un errore di calcolo.
  - Vale ovunque: interfaccia dei tre script, esportazione CSV ed esportazione Excel.
  - Nel foglio Excel il simbolo finisce nel **formato delle celle**, non nel testo: le celle restano numeri e le formule del foglio continuano a calcolare.
  - La scelta è salvata in `repertoire_settings.json`, un file separato dal database delle banche dati: i database esistenti non vengono toccati e, se il file manca, si assume l'euro.
- **Nuovo modulo condiviso `Settings.lua`** (va in `Fusion/Modules/Lua/`, come `LogManager` e `BugReportDialog`). Chi installa a mano deve copiarlo lì, altrimenti gli script non partono.

### Note
- Cambiando valuta, le finestre già aperte (Calculator, Monitor) mostrano il simbolo nuovo dopo essere state riaperte.
- Il simbolo va sempre prima della cifra. Il separatore decimale resta il punto, come nelle versioni precedenti.
- Chi licenzia da archivi in valute diverse nello stesso progetto deve convertire a mano prima di inserire le tariffe: lo strumento mostra un solo simbolo per tutto e non applica tassi di cambio.

## [1.2.14] — 2026-10-26

### Modificato
- **Indirizzo delle segnalazioni bug**: dall'indirizzo personale dell'autore a **`tomfilmeditor.tools@gmail.com`**, casella dedicata agli strumenti. Cambia solo il destinatario: il pulsante 🐛, l'avviso privacy e le informazioni di sistema raccolte funzionano come prima.
  - Aggiornati: i tre script, `BugReportDialog.lua`, `RepertoireDB_README.txt`, `bug_management_config.json`, `INSTALL.txt`
  - Il pulsante ☕ **non è toccato**: `paypal.me/acoffeefortom` è un link che non contiene alcun indirizzo email
- **Il pacchetto distribuito non contiene più il listino tariffe.** `Templates/RepertoireDB_Archivi.csv` (12 archivi con le tariffe reali negoziate e note commerciali) è sostituito da `RepertoireDB_Archivi_template.csv`: stessi archivi, **tariffe a zero**, con istruzioni su come compilarle e l'avvertenza che molti archivi applicano costi fissi per ordine che lo strumento non calcola.
  - Il generatore dell'installer ora **si ferma con errore** se trova un archivio reale accompagnato da una tariffa: la protezione non dipende più dall'attenzione di chi genera il pacchetto

### Da sapere per chi aggiorna
- Il tuo `repertoire_db.json` e la cartella `memories/` non vengono toccati: le banche dati configurate restano
- Se usavi `Templates/RepertoireDB_Archivi.csv` come riferimento, nel pacchetto ora trovi la versione con le tariffe da compilare

## Documentazione — 13 ottobre 2026 (nessuna modifica al codice)

- `RepertoireDB_README.txt` allineato alla 1.2.13 (era fermo alla 1.2.9, 844 → 1094 righe). Aggiunto quello che mancava: avviso che **serve Resolve Studio** (UIManager è Studio-only dalla 19.1), installazione tramite installer, le **due cartelle di destinazione** e l'errore `module 'LogManager' not found` che si ottiene sbagliandole, modello di pricing **Forfait** (c'era dalla 1.2.8 ma non era documentato), tab **Memorie**, **Utilizzo Minimo** e colonna "Secondi Scoperti", **file di log** e sua rotazione, **avviso privacy** nella segnalazione bug, export **Excel a tre fogli**, campo `utilMin` nella struttura JSON, i due moduli condivisi nella sezione per sviluppatori.
- Aggiunto `INSTALL.txt` bilingue EN/IT al pacchetto di installazione (prima le istruzioni esistevano solo a schermo durante l'installazione).
- Nota: la versione **1.2.7 non risulta documentata** da nessuna parte — né qui né nel README. Probabile salto di numerazione fra 1.2.6 e 1.2.8, segnalato come tale invece di inventarne il contenuto.
- Questo file non contiene le voci dalla 1.2.1 alla 1.2.7: quella cronologia esiste solo nel README. Da sanare se il CHANGELOG viene pubblicato.

## [1.2.13] — 2026-08-06

### Aggiunto
- **BugReportDialog.lua — Modulo dialog segnalazione bug con Privacy Notice**
  - Modulo Lua riutilizzabile via `require("BugReportDialog")` in tutti gli script RepertoireDB
  - Privacy notice visibile prima di compilare l'email (trasparenza dati)
  - Template email pre-compilato con info sistema (OS, Resolve, Lua version)
  - Funzioni pubbliche: `:show()` (mostra notice), `:sendEmail()` (apre Mail.app), `:createButton()`
  - Supporto cross-platform: AppleScript per macOS, mailto: per Windows/Linux

- **BugReportDialog.py — Modulo dialog segnalazione bug per Python**
  - Modulo Python riutilizzabile via `from BugReportDialog import BugReportDialog`
  - Privacy notice visibile in console prima di inviare
  - Template email pre-compilato con info sistema (OS, Python, Resolve version)
  - Metodi: `show_privacy_notice()`, `send_email_macos()`, `send_email_windows()`, `handle_bug_report()`
  - Supporto cross-platform con fallback automatico

### Modificato
- **Config.lua (v1.2.13)**
  - Integrato `BugReportDialog:show()` e `BugReportDialog:sendEmail()`
  - Rimossa logica inline di reportBug() — ora usa il modulo
  - Aggiunta privacy notice visibile prima di compilare l'email

- **Calculator.lua (v1.2.13)**
  - Integrato `BugReportDialog:show()` e `BugReportDialog:sendEmail()`
  - Rimossa logica inline di reportBug() — ora usa il modulo
  - Aggiunta privacy notice visibile prima di compilare l'email

- **Monitor.lua (v1.2.13)**
  - Integrato `BugReportDialog:show()` e `BugReportDialog:sendEmail()`
  - Rimossa logica inline di reportBug() — ora usa il modulo
  - Aggiunta privacy notice visibile prima di compilare l'email

- **MarkerClipManager.py (v1.2.13)**
  - Integrato `BugReportDialog.handle_bug_report()`
  - Rimossa logica inline di report_bug() — ora usa il modulo
  - Aggiunta privacy notice visibile prima di compilare l'email

### Note
- Privacy notice trasparente su dati inviati (OS, versioni, timeline)
- Nessun dato sensibile incluso: no password, API key, credenziali
- Utente può editare email prima di inviare
- Client di posta nativo aperto automaticamente (Mail.app/Windows/xdg-open)

---

## [1.2.12] — 2026-08-06

### Aggiunto
- **LogManager.lua — Sistema centralizzato di logging**
  - Modulo Lua riutilizzabile via `require("LogManager")` in tutti gli script
  - 5 livelli di log: DEBUG, INFO, WARNING, ERROR, CRITICAL
  - Rotazione automatica log per SIZE (5 MB, non per data)
  - Percorso cross-platform unificato: `~/Library/Logs/RepertoireDB/`
  - Funzioni pubbliche: `LogManager:init()`, `:debug()`, `:info()`, `:warn()`, `:error()`, `:critical()`
  - Utility: `getTail(n)`, `readAll()` per debugging

- **log_manager.py — Singleton Python per logging**
  - Modulo Python riutilizzabile via `from log_manager import log`
  - Istanza globale preconfigurata: `log.info()`, `log.error()`, ecc.
  - Stessi 5 livelli e percorsi cross-platform di LogManager.lua
  - Serializzazione JSON per dati strutturati

### Modificato
- **Config.lua (v1.2.12)**
  - Migrato a `LogManager:init()` + LogManager centralizzato
  - Rimosso `getLogPath()`, `logMessage()`, `rotateLog()` (ora in LogManager.lua)
  - Logging aggiunto:
    - loadDB(): `LogManager:info()` — "#banche caricate"
    - saveDB(): `LogManager:info/error()` — successo/permessi insufficienti
    - importFromJSON(): `LogManager:error/info()` — errore JSON / "#banche importate"
    - reportBug(): `LogManager:warn()` — segnalazione inviata

- **Calculator.lua (v1.2.12)**
  - Migrato a `LogManager:init()` + LogManager centralizzato
  - Logging aggiunto (7 punti critici):
    - Timeline aperta: `LogManager:info()` — "Timeline ... aperta"
    - Scansione clip: `LogManager:debug()` — "Clip rilevati: N"
    - Deduplicazione: `LogManager:debug()` — "N duplicati trovati"
    - Calcolo completato: `LogManager:info()` — "Totale: €..."
    - Export CSV: `LogManager:info()` — "N righe scritte"
    - Export XLSX: `LogManager:info/error()` — success/fallback Python non trovato

- **Monitor.lua (v1.2.12)**
  - Migrato a `LogManager:init()` + LogManager centralizzato
  - Logging aggiunto (6 punti critici):
    - Startup: `LogManager:info()` — "Monitor avviato"
    - Banks caricati: `LogManager:info()` — "N banche Video"
    - Aggiornamento timeline: `LogManager:debug()` — "Scan in corso"
    - Errori calcolo: `LogManager:error()` — "Errore calcolo durata"
    - Chiusura: `LogManager:info()` — "Monitor chiuso"

- **MarkerClipManager.py (v1.2.12)**
  - Integrato `from log_manager import log`
  - Logging aggiunto (8 punti critici):
    - GUI inizializzata: `log.info()` — "GUI inizializzata - PySide6 caricato"
    - Resolve connesso: `log.info()` — "Resolve connesso"
    - Timeline caricata: `log.info()` — "N marker trovati"
    - Marker modificato: `log.debug()` — "Marker ID X modificato (color/track)"
    - Errore modifica: `log.error()` — "Impossibile modificare marker"
    - Export CSV: `log.info()` — "N marker scritti"
    - Import CSV: `log.info()` — "N marker importati"
    - Errori generici: `log.error()` — exception type + message

### Compatibilità
- Tutti gli script aggiornati a v1.2.12 con LogManager centralizzato
- Configuration JSON identico (nessun breaking change)
- Percorsi log unificati cross-platform (macOS/Windows)
- reportBug() integrato con lettura automatica del log

## [1.2.11] — 2026-08-06

### Aggiunto
- **Utilizzo Minimo** per banca dati: campo `utilMin` (secondi) configurabile in Config.lua e visibile nella colonna "Util.Min." del tree banche
  - Se l'utilizzo effettivo in montaggio è inferiore al minimo, il costo viene calcolato sul minimo impostato
  - Superata la soglia del minimo, il calcolo torna sull'utilizzo effettivo normale
  - Applicato a tutti i modelli temporali (Al secondo, Al minuto, A blocchi); ignorato per "A clip" e "Forfait"
  - Salvato nel JSON di configurazione e propagato all'export XLSX
- **Pulsante "⏭️  Apri Calcolatore"** in Config.lua
  - Posizionato in basso centrato tra "Annulla" e le icone emoji
  - Chiude Config e apre Calculator via `dofile()`
- **Informazioni deficit utilizzo minimo** nel JSON export (Calculator.lua)
  - Nuovo campo `dbUncoveredSec`: secondi non utilizzati sotto la soglia (se utilizzo < utilMin)
  - Nuovo campo `dbTotalSec`: secondi totali per banca (utile per calcoli sconti e reporting)
- **Export XLSX aggiornato** (RepertoireDB_xlsx.py v1.2.11):
  - Foglio Config: nuova colonna F "Utilizzo Min. (sec)" editabile, pre-valorizzata dal JSON
  - Foglio Riepilogo colonna B: formula aggiornata con `MAX(durata_effettiva, utilMin)` per i modelli temporali
  - Foglio Riepilogo: **rinominata colonna C** "Somma Clip €" → "Occorrenze" (formato numerico, no €)
  - Foglio Riepilogo: **nuova colonna H "Secondi Scoperti"** — mostra deficit se utilizzo < minimo (es. "Min 300s - Usati 120s - Scoperti 180s")
  - Colonne sconto spostate: soglie in H-Q, conversioni nascoste in R-V (erano G-P e Q-U)

- **Sistema di logging completo** (Config.lua + Calculator.lua + MarkerClipManager.py)
  - Percorso unificato: `~/Library/Logs/RepertoireDB/` (macOS) / `%LOCALAPPDATA%/Blackmagic Design/DaVinci Resolve/Logs/RepertoireDB/` (Windows)
  - Livelli: INFO, WARNING, ERROR, DEBUG con timestamp YYYY-MM-DD HH:MM:SS
  - Rotazione automatica: log cancellato se > 7 giorni
  - Integrazione BtnBug (🐛):
    - **macOS**: AppleScript apre Mail.app con log allegato vero
    - **Windows**: mailto con log completo nel body
  - Funzioni uniformi: `getLogPath()`, `logMessage(level, message)`, `rotateLog()`
  - Implementato in:
    - Config.lua (Lua + pcall error handling)
    - Calculator.lua (Lua + pcall error handling)
    - MarkerClipManager.py (Python + try-except)
  - **Documento standard**: `LOGGING_STANDARD.md` — guida uniforme per script futuri (template Lua + Python, best practices, checklist)
  - File di esempio: `repertoire_db_example.log` (Desktop)
  - Guida integrazione: `LOGGING_INTEGRATION_GUIDE.md` (Desktop)

### Modificato
- Dimensioni finestre aumentate per evitare sovraffollamento UI:
  - Config.lua: Geometry 840→920 (width), 760→820 (height); MinimumSize 900×800
  - Calculator.lua: Geometry 1000→1100 (width), 660→720 (height); MinimumSize 1080×700
- Funzione `reportBug()` aggiornata: legge e allega file di log alle segnalazioni

## [1.2.10] — 2026-07-31

### Modificato
- **Export XLSX a 3 fogli con formule cross-sheet** (RepertoireDB_xlsx.py):
  - Foglio **Config**: tabella banche dati editabile (FPS in B1, tariffe e modelli)
  - Foglio **Segmenti**: formule collegate a Config per Modello (VLOOKUP), Durata (da frame helpers), Costo (VLOOKUP); colonne helper N–S nascoste per aritmetica TC; clip deduplicate con fill arancio e costo statico (0)
  - Foglio **Riepilogo**: VLOOKUP/COUNTIF/SUMPRODUCT cross-sheet per ogni banca; colonna Sconto % editabile; SUBTOTALE per categoria; TOTALE GENERALE; legenda
  - Bordini celle sottili su tutti i dati (visibili come nel precedente export)
  - Modello Forfait supportato nella formula Riepilogo (costo fisso)
- **`dupStatus` esportato in JSON** (RepertoireDB_Calculator.lua): ogni segmento ora include il campo `dupStatus` ("nuovo"/"duplicato"/"parziale") usato dallo script xlsx per il fill arancio e il costo statico

## [1.2.9] — 2026-07-31

### Aggiunto
- **Tab "Memorie"** nella finestra Config: salva e richiama snapshot dell'intera configurazione
  - Salva la configurazione attuale come file JSON nominato (cartella `memories/` nella directory script)
  - Carica una memoria: sostituisce completamente la configurazione attuale (con alert di conferma)
  - Elimina una memoria dalla libreria
  - Prima del caricamento, l'attuale configurazione viene salvata automaticamente come `_previous.json`
  - Pulsante "Ripristina precedente" per annullare l'ultimo caricamento

### Uniformato (tutti gli script)
- **Bottoni emoji grandi** (📖 Guida / ☕ Offrimi un caffè / 🐛 Riporta bug) con gradiente colorato
  propagati a Calculator e Monitor; stile gradiente applicato anche a MarkerClipManager (Python QSS)
- **SortingEnabled = true** su ResultTree (Calculator) — sort nativo Qt sulle colonne del calcolo
- **BtnBug apre PayPal** simultaneamente alla mail in tutti gli script incluso MarkerClipManager
- **Monitor**: aggiunto 📖 BtnReadme e ☕ BtnCoffee (prima assenti); corretta label versione hardcoded

## [1.2.8] — 2026-07-30

### Aggiunto
- Modello di pricing **Forfait**: prezzo fisso per l'intera banca dati, indipendente
  da numero di clip e durata. Disponibile per Video, Fotografie e Giornali.
  - Tutti gli eventi della banca vengono elencati con costo "compreso nel forfait"
  - Il prezzo forfait compare nel subtotale e nel totale generale
  - Le clip con modello Forfait non generano "secondi inutilizzati" o note di arrotondamento

## [1.2.0] — 2026-05-16

### Aggiunto
- Bottone donazione PayPal (☕) nella UI del Calculator
- Header MIT License in tutti e tre gli script
- Costante `SCRIPT_VERSION` / `VERSION` in tutti gli script
- Documentazione funzioni principali (commenti input/output)
- README sezione "Per sviluppatori" con struttura file e guida al codice
- README sezione "Nota importante — Transizioni" con spiegazione del limite
- CHANGELOG.md (questo file)
- LICENSE.md (MIT)

### Rimosso
- Tutto il codice di rilevamento automatico transizioni (EDL / Index CSV):
  - `parseIndexCSV()` — parsing CSV timeline
  - `findLatestIndexFile()` — ricerca file CSV automatica
  - `autoLoadEDLIfAvailable()` — caricamento automatico
  - `testDetectSceneCuts()`, `exploreTimelineObject()`, `deepExploreTimeline()` — debug API
  - Variabili di stato `lastEdlDurations`, `transitionsLoaded`
  - Pulsanti UI "Carica Index CSV" e "Ricerca Automatica"
  - Label UI "LblTransStatus" e "LblTransDisclaimer"
- File obsoleti dalla cartella script:
  - `FINAL_VERIFICATION.txt`
  - `INTEGRATION_COMPLETE.md`
  - `INTEGRATION_VERIFICATION.md`
  - `TRANSITION_DETECTION_GUIDE.md`
  - Cartelle `_backup/` e `backup_*/`

### Modificato
- Licenza da Creative Commons CC BY-NC-SA 4.0 a MIT
- Versione aggiornata a 1.2.0 in tutti gli script
- README riscritto con sezione transizioni, sezione sviluppatori e link donazione
- Separatori di sezione nel codice uniformati

### Nota tecnica
Il rilevamento automatico delle transizioni (dissolve, fade) è stato rimosso
perché l'API Lua di DaVinci Resolve non espone metodi per accedere agli
oggetti transizione su una timeline. Questa è una limitazione deliberata
dell'API Blackmagic che non ha workaround affidabili allo stato attuale.
Vedi README per istruzioni su come gestire le transizioni manualmente.


## [1.1.0] — 2026-05

### Aggiunto
- Lettura durata sorgente via API nativa DaVinci Resolve (`GetSourceStartFrame` / `GetSourceEndFrame`)
- Supporto tipi media: Fotografie e Giornali (modello "A clip")
- Monitor floating (`RepertoireDB_Monitor.lua`) — riepilogo banche dati in tempo reale
- Deduplicazione frame sorgente ripetuti in timeline
- Visualizzazione ordine di montaggio nel dettaglio
- Esportazione CSV con BOM UTF-8 (compatibilità Excel/Numbers)
- Rilevamento retime: Slow Motion, Time Warp, Freeze Frame, Reverse
- Supporto sconti progressivi

### Modificato
- Calcolo durata sorgente: da timecode EDL a API nativa Resolve
- Arrotondamento al livello di banca aggregata (non per singolo clip)

### Rimosso
- Dipendenza da file EDL per il calcolo della durata sorgente


## [1.0.0] — 2026-03

### Prima versione pubblica
- Configurazione banche dati via CSV/JSON (`RepertoireDB_Config.lua`)
- Calcolo costi per banche Video con modelli Al minuto / Al secondo / A blocchi / A clip
- Tagging clip via campo Keywords del Media Pool
- Esportazione preventivo CSV
- Supporto sconti flat e progressivi
- Compatibilità DaVinci Resolve 19/20, macOS e Windows
