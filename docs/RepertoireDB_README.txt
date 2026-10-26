==================================================================
RepertoireDB — Gestione Costi Materiale di Repertorio
Versione 1.2.14
==================================================================

Autore:  Tommaso Feraboli — Film Editor
Licenza: MIT — vedi LICENSE.md
         Copyright (c) 2024-2026 Tommaso Feraboli
         Il nome dell'autore e questo avviso devono rimanere in
         tutti i file derivati e ridistribuiti.

Compatibile con DaVinci Resolve 19/20 — macOS e Windows

  !! RICHIEDE DaVinci Resolve STUDIO !!

  Dalla versione 19.1 di Resolve, l'interfaccia grafica usata da
  questi script (UIManager) e disponibile solo nella versione
  Studio. Con Resolve gratuito gli script non si aprono.

==================================================================
PROGETTO OPEN SOURCE — DONAZIONI VOLONTARIE
==================================================================

RepertoireDB e un progetto open source gratuito sviluppato da un
film editor per altri film editor.

Se lo trovi utile, considera di supportarne lo sviluppo con una
donazione volontaria su PayPal:

  https://paypal.me/acoffeefortom

Anche un caffe fa la differenza. Grazie!


==================================================================
INSTALLAZIONE
==================================================================

MODO CONSIGLIATO — L'INSTALLER (dalla v1.2.13)
-----------------------------------------------
Scarica l'installer per il tuo sistema e lanciarlo: mette ogni file
al posto giusto e prepara tutto da solo.

  macOS   : RepertoireDB_X.Y.Z_Install_macOS.command
            CLIC DESTRO sul file > Apri.
            NON fare doppio clic: l'installer non e firmato con un
            certificato Apple e il doppio clic viene bloccato con un
            avviso su uno "sviluppatore non identificato". Il clic
            destro fa comparire il pulsante "Apri", che il doppio
            clic non mostra.

  Windows : RepertoireDB_X.Y.Z_Install_Windows.cmd
            Doppio clic. Se compare l'avviso blu di SmartScreen,
            scegli "Ulteriori informazioni" > "Esegui comunque".

L'installer non sovrascrive mai il tuo repertoire_db.json ne la
cartella memories/: aggiornare di versione non fa perdere le banche
dati configurate.


INSTALLAZIONE MANUALE — ATTENZIONE: DUE CARTELLE DIVERSE
---------------------------------------------------------
Dalla v1.2.12 i file non vanno piu tutti nella stessa cartella.
I due moduli condivisi vanno in una cartella DIVERSA da quella degli
script: se finiscono nel posto sbagliato, gli script non partono e
danno l'errore "module 'LogManager' not found".

1) SCRIPT — nella cartella degli script Fusion:

  macOS  : ~/Library/Application Support/Blackmagic Design/
            DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/

  Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\
            Fusion\Scripts\Comp\RepertoireDB\
           (su alcune installazioni la cartella ha un livello in piu:
            ...\DaVinci Resolve\Support\Fusion\Scripts\Comp\RepertoireDB\
            Usa quella che esiste gia sul tuo computer.)

  Linux  : ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/
            RepertoireDB/

  File:
    RepertoireDB_Calculator.lua   — calcolo costi in timeline
    RepertoireDB_Config.lua       — configurazione banche dati e tagging
    RepertoireDB_Monitor.lua      — monitor floating: banche e durate
    RepertoireDB_Installer.lua    — verifica e installa Python + openpyxl
    RepertoireDB_xlsx.py          — generatore XLSX (chiamato dal Calculator)
    repertoire_db.json            — database banche dati (creato al primo uso)
    RepertoireDB_README.txt       — questa guida
    CHANGELOG.md                  — cronologia delle versioni
    LICENSE.md                    — licenza MIT
    Templates/                    — CSV di esempio e template

2) MODULI CONDIVISI — nella cartella dei moduli Lua:

  macOS  : ~/Library/Application Support/Blackmagic Design/
            DaVinci Resolve/Fusion/Modules/Lua/

  Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\
            Fusion\Modules\Lua\

  File:
    LogManager.lua        — sistema di log condiviso (v1.2.12+)
    BugReportDialog.lua   — finestra di segnalazione bug (v1.2.13+)

  Perche una cartella diversa: Resolve cerca i moduli richiamati con
  require() solo in Modules/Lua, non nella cartella degli script.


PREREQUISITI
------------
  - DaVinci Resolve STUDIO 19 o 20 (vedi avviso in cima a questa guida)
  - Solo per l'esportazione in Excel (.xlsx): Python 3 con openpyxl.
    Esegui RepertoireDB_Installer.lua da Workspace > Scripts per
    verificare e installare automaticamente i prerequisiti.
  - Dipendenza Lua: dkjson (inclusa in DaVinci Resolve, non richiede
    installazione separata).

Avvio script:
  Workspace > Scripts > Comp > RepertoireDB_Config
  Workspace > Scripts > Comp > RepertoireDB_Calculator
  Workspace > Scripts > Comp > RepertoireDB_Monitor


INSTALLAZIONE SU LINUX (manuale)
==================================

Se utilizzi Linux, estrai manualmente i file:

  mkdir -p ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/Templates

  cd /percorso/dove/hai/scaricato/RepertoireDB

  cp RepertoireDB_Calculator.lua \
     RepertoireDB_Config.lua \
     RepertoireDB_Monitor.lua \
     RepertoireDB_README.txt \
     ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/

  cp Templates/*.csv \
     ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB/Templates/

Oppure, se i file sono in un archivio tar.gz:

  mkdir -p ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/RepertoireDB
  tar -xzf RepertoireDB_1.2.5.tar.gz -C ~/.local/share/DaVinciResolve/Fusion/Scripts/Comp/


==================================================================
WORKFLOW COMPLETO
==================================================================

PASSO 1 — Configurare le banche dati  (RepertoireDB_Config)
------------------------------------------------------------
Avvia RepertoireDB_Config da Workspace > Scripts.

Puoi aggiungere banche dati in tre modi:

  A) Manualmente
     Compila il modulo a destra della finestra:
       - Nome banca (es. "Getty Images")
       - Tipo media: Video / Fotografie / Giornali
         (per Fotografie e Giornali il modello e fisso "A clip")
       - Modello di pricing (Al minuto / Al secondo / A blocchi / A clip / Forfait)
         (solo per banche Video; Forfait e disponibile anche per Fotografie e Giornali)
       - Tariffa in euro per unita
       - Sconti opzionali (vedi sezione SCONTI)
       - Calcola audio eccedente: se attivo, i secondi audio senza
         copertura video di questa banca vengono fatturati al 50%
         della tariffa (configurabile per singola banca, vedi
         sezione AUDIO ECCEDENTE)
     Clicca "Salva modifiche" per registrare la banca.
     Clicca "+ Aggiungi" per aggiungere uno sconto: la banca viene
     salvata automaticamente con lo sconto incluso.

  B) Importazione da CSV
     Clicca "Importa JSON/CSV..." e seleziona un file con il formato
     descritto nella sezione FORMATO CSV. Il file RepertoireDB_Archivi.csv
     incluso contiene le banche dati piu comuni gia precompilate.

  C) Importazione da JSON
     Clicca "Importa JSON/CSV..." e seleziona un file .json esportato
     da un'altra installazione di RepertoireDB.

  D) Esportazione CSV banche dati
     Clicca "Esporta CSV" nella toolbar del Config per salvare tutte le
     banche dati (inclusi sconti e impostazioni audio eccedente) in un
     file CSV pronto per essere reimportato su un'altra macchina senza
     perdita di dati. Il file e compatibile con la funzione
     "Importa JSON/CSV..." (vedi sezione FORMATO CSV).

La configurazione viene salvata in repertoire_db.json nella stessa
cartella degli script. E un file JSON testuale, copiabile come backup.


TAB "MEMORIE" — SNAPSHOT DELLA CONFIGURAZIONE (v1.2.9+)
--------------------------------------------------------
Nella finestra Config, la tab "💾 Memorie" salva e richiama
configurazioni complete. Utile quando lavori su produzioni diverse con
listini diversi: una memoria per produzione, e si cambia in un clic.

  - "Salva memoria": salva la configurazione attuale con un nome.
    I file finiscono nella cartella memories/ accanto agli script
  - "Carica memoria": SOSTITUISCE completamente la configurazione
    attuale (compare un avviso di conferma prima di procedere)
  - "Elimina memoria": rimuove una memoria dalla libreria
  - "Ripristina precedente": annulla l'ultimo caricamento

Rete di sicurezza: prima di ogni caricamento la configurazione attuale
viene salvata automaticamente come _previous.json. Se carichi la
memoria sbagliata, "Ripristina precedente" rimette tutto a posto.


TIPI DI MEDIA
-------------
Ogni banca dati appartiene a una delle tre categorie:

  Video       — materiale video: durata sorgente, tutti i modelli di pricing
  Fotografie  — fotografie: costo per clip unica (flat), senza durata
  Giornali    — articoli di giornale: come Fotografie

Per le banche Fotografie e Giornali:
  - Il modello di pricing e fisso "A clip" (una tariffa per file sorgente
    unico presente in timeline, indipendente dal numero di usi)
  - Nel Calculator, il RIEPILOGO mostra il numero di clip e il costo totale,
    raggruppati nelle sezioni VIDEO / FOTOGRAFIE / GIORNALI
  - Nel Monitor, le sezioni Fotografie e Giornali sono nascoste per default;
    attivale con la checkbox "Mostra Fotografie e Giornali"


PASSO 2 — Taggare le clip nel Media Pool  (RepertoireDB_Config)
---------------------------------------------------------------
Ogni clip di repertorio deve avere nel campo "Keywords" del Media Pool
il nome esatto della banca dati di appartenenza (es. "Getty Images").
Il Calculator usa questo campo per abbinare clip e tariffa.

KEYWORD MULTIPLE — COMPATIBILITA CON ALTRE WORKFLOW
  A partire dalla v1.2.4, il campo Keywords puo contenere piu valori
  separati da punto e virgola (;), virgola (,) o a capo. RepertoireDB
  riconosce la banca dati anche se sono presenti altre keyword non
  correlate al repertorio (es. "RAI COM;Documentario;Seveso").
  Il tagging e la rimozione agiscono solo sulle keyword di repertorio,
  lasciando invariate le altre.

Come assegnare i tag con il pannello integrato:

  1. Nel Media Pool di DaVinci Resolve, seleziona una o piu clip
     di repertorio della stessa banca dati.

  2. In RepertoireDB_Config, clicca il pulsante "Tagga Clip Selezionate".
     Si apre una finestra con:
       - Il numero di clip attualmente selezionate nel Media Pool
       - Un menu a tendina con tutte le banche dati configurate
       - I pulsanti "Applica" e "Rimuovi keyword"

  3. Scegli la banca dati dal menu e clicca "Applica".
     La keyword di repertorio viene aggiunta alle clip selezionate
     senza modificare le altre keyword gia presenti.

  4. SENZA CHIUDERE la finestra, torna nel Media Pool, seleziona
     un altro gruppo di clip, scegli una banca diversa e clicca
     di nuovo "Applica". La finestra legge sempre la selezione
     corrente al momento del clic.

  5. Per rimuovere il tag di repertorio da un gruppo di clip,
     selezionale e clicca "Rimuovi keyword". Vengono rimosse solo
     le keyword corrispondenti a banche dati configurate in RepertoireDB;
     le altre keyword rimangono intatte.

  6. Chiudi la finestra quando hai finito il tagging.

Nota: il campo Keywords e case-sensitive — "Getty Images" e
"getty images" sono banche dati diverse. Usa sempre il menu a
tendina per evitare errori di battitura.


PASSO 3 — Montare la timeline normalmente
-----------------------------------------
Monta il progetto come di consueto. Le clip di repertorio taggiate
possono apparire una o piu volte in timeline, su tracce diverse,
con tagli, retime, slow motion, time warp, freeze frame o reverse.
Il Calculator gestisce tutti questi casi automaticamente.


PASSO 4 — Calcolare i costi  (RepertoireDB_Calculator)
-------------------------------------------------------
Avvia RepertoireDB_Calculator da Workspace > Scripts.

  1. Seleziona la timeline dal menu a tendina in alto.

  2. Clicca "Calcola". Lo script analizza tutte le tracce video,
     legge il campo Keywords di ogni clip, calcola la durata
     sorgente reale e applica le tariffe.

  3. Il risultato appare nell'albero suddiviso in due sezioni:

     RIEPILOGO PER CATEGORIA  (sempre in cima)
       Organizzato in tre sezioni: VIDEO / FOTOGRAFIE / GIORNALI.
       Ogni sezione mostra le banche attive con costo netto,
       eventuali sconti, subtotale di categoria e totale generale.

       Video: mostra durata totale sorgente per banca e totale.
       Fotografie/Giornali: mostra numero di clip uniche e costo.

       Le note ARROTONDATO A indicano che il totale aggregato per
       banca differisce dalla somma proporzionale per effetto del
       ceil al secondo/minuto/blocco superiore. Il badge
       "⚠ X sec inutilizzati" mostra i secondi pagati ma non
       utilizzati per effetto dell'arrotondamento.

     DETTAGLIO  (sotto il separatore)
       Lista delle singole clip con durata sorgente e costo
       proporzionale. Si puo visualizzare in due modi:

       - "Per banca": clip raggruppate per banca dati, ordine alfabetico.
       - "Ordine di montaggio": clip in ordine cronologico
          di apparizione in timeline (per TL In).

     Cambia la vista dal menu "Vista" nella toolbar senza
     dover ricalcolare.

  4. Clicca "Esporta" per salvare il preventivo. Si apre un dialogo
     dove scegli il formato (CSV o Excel) e l'ordinamento della
     sezione segmenti (ordine di montaggio o per banca dati).

     CSV — un unico file di testo, apribile in qualsiasi foglio di
     calcolo. Contiene:
       - Riga 1: avviso che il calcolo e approssimativo
       - Subtotali per banca raggruppati per categoria
         (VIDEO / FOTOGRAFIE / GIORNALI), con costo lordo, somma
         proporzionale, sconto, costo netto, durata totale,
         "Secondi Scoperti" (vedi UTILIZZO MINIMO) e note di
         arrotondamento
       - Sezione AUDIO ECCEDENTE, se presente
       - TOTALE GENERALE netto
       - Banche con costo da definire (non incluse nel totale)
       - Dettaglio segmenti: ogni clip con Src In, Src Out, durata
         sorgente, Rec TC In/Out, durata montato, costo segmento
         (dove applicabile) e note retime

     EXCEL (.xlsx) — tre fogli collegati fra loro da formule, cosi
     puoi cambiare una tariffa e vedere aggiornarsi tutto il
     preventivo senza rilanciare lo script (v1.2.10+):
       - Foglio "Config": le banche dati, con tariffe e modelli
         modificabili, e il frame rate in B1
       - Foglio "Segmenti": tutte le clip, con filtri attivi su ogni
         colonna; le clip duplicate sono evidenziate in arancio e
         contate a costo zero
       - Foglio "Riepilogo": i totali per banca, con la colonna
         Sconto % modificabile, i subtotali per categoria e il
         totale generale

     L'esportazione Excel richiede Python 3 con openpyxl: vedi
     PREREQUISITI.


PASSO 5 — Monitor in tempo reale  (RepertoireDB_Monitor)
---------------------------------------------------------
Avvia RepertoireDB_Monitor da Workspace > Scripts.

La finestra floating mostra, per la timeline corrente:

  - Le banche dati Video in uso, con la durata sorgente unica
    (frame deduplicati) per ciascuna.
  - Se piu banche Video sono presenti: totale video.
  - Con la checkbox "Mostra Fotografie e Giornali" attivata:
    numero di clip uniche e costo totale per ogni banca
    Fotografie/Giornali, raggruppate per categoria con subtotale.

Clicca "Aggiorna" per rileggere la timeline dopo modifiche
al montaggio o alla configurazione.

SELEZIONE CLIP PER BANCA (v1.2.5+)
  Cliccando il nome di una banca nella lista il Monitor:

    1. Aggiunge un flag colorato a tutti i clip della banca
       in timeline. Ogni banca riceve un colore univoco e
       deterministico (lo stesso nome ottiene sempre lo stesso
       colore). Se le banche configurate superano i 16 colori
       disponibili, le banche eccedenti ricevono 2 flag
       simultanei per distinguerle.

    2. Naviga il playhead al primo clip della banca in timeline.

    3. Seleziona automaticamente tutti i clip della banca
       tramite il menu Timeline > Select Clips > By Flag Color.
       I clip risultano selezionati (outline rosso) e rispondono
       ai comandi successivi: cambio colore, copia, ecc.

    4. Alla barra di stato in basso mostra:
         ▶ NomeBanca [Colore] — N segmenti

  Quando si clicca una banca diversa, i flag della banca
  precedente vengono rimossi e applicati a quella nuova.
  Alla chiusura del Monitor tutti i flag vengono ripristinati.

  Nota: la funzione richiede macOS e i permessi di accessibilita
  per DaVinci Resolve (Impostazioni di Sistema > Privacy e sicurezza
  > Accessibilita). Su Windows la selezione automatica non e
  disponibile; flag e navigazione playhead funzionano ugualmente.

Il Monitor non calcola i costi finali con arrotondamento e sconti;
usa il Calculator per il preventivo definitivo.


==================================================================
FUNZIONALITA AVANZATE
==================================================================

RILEVAMENTO RETIME
------------------
Lo script rileva automaticamente gli effetti di velocita applicati
alle clip e li segnala nel campo Dettaglio e nella colonna Note del CSV:

  Time Warp X%      — clip accelerata (es. 200% = durata sorgente doppia
                       rispetto alla durata in timeline)
  Slow Motion X%    — clip rallentata (es. 50% = sorgente usa meta dei
                       frame mostrati in timeline)
  Freeze Frame      — un singolo frame sorgente ripetuto
  Reverse           — clip riprodotta al contrario (rilevamento best-effort)

In tutti i casi il costo e calcolato sulla durata sorgente reale,
indipendentemente dalla velocita di riproduzione in timeline.


DEDUPLICAZIONE FRAME RIPETUTI
------------------------------
Se la stessa clip sorgente appare piu volte in timeline con gli
stessi fotogrammi sorgente (es. lo stesso momento del file usato in
due punti del montaggio), quei fotogrammi vengono conteggiati UNA
SOLA VOLTA ai fini del costo.

Nella vista "Per banca", le occorrenze ripetute vengono mostrate come
righe indentate con la dicitura:

  RIPETUTO — non conteggiato
  parziale — X unici su Y   (sovrapposizione parziale)

Il costo della banca e calcolato solo sui frame unici.

Per le banche Fotografie/Giornali, la deduplicazione e sul file sorgente
(GetUniqueId): lo stesso file usato N volte in timeline conta come 1 clip.


AUDIO ECCEDENTE
---------------
Per le banche Video che fatturano separatamente il materiale audio
senza copertura video (es. voce off o musica originale di repertorio
usata oltre il video), e possibile abilitare il calcolo dell'audio
eccedente per singola banca.

Configurazione:
  Nel pannello banca dati del Config, attiva la checkbox
  "Calcola audio eccedente". Se attiva, i secondi audio non coperti
  da video della stessa banca vengono fatturati al 50% della tariffa
  standard.

Il calcolo avviene automaticamente nel Calculator. I secondi audio
eccedenti sono mostrati nella sezione di riepilogo di quella banca.
L'impostazione e per-banca: alcune banche possono avere il calcolo
audio attivo e altre no.


SECONDI INUTILIZZATI (ARROTONDAMENTO)
--------------------------------------
Per i modelli "Al minuto" e "A blocchi", il totale aggregato per banca
viene arrotondato all'unita di fatturazione successiva. I secondi pagati
ma non utilizzati a causa di questo arrotondamento vengono mostrati nel
riepilogo con il badge:

  ⚠ X sec inutilizzati → €Y.YY extra

Il badge appare solo nelle righe di riepilogo banca (non nei dettagli
delle singole clip), e mostra il costo extra dovuto al solo
arrotondamento. Per i modelli "Al secondo" e "A clip" il badge non
compare (nessun arrotondamento a unita superiori).


UTILIZZO MINIMO (v1.2.11+)
---------------------------
Molti archivi fatturano un minimo anche se usi meno materiale: per
esempio 30 secondi minimi anche se in montaggio ne usi 6.

Configurazione:
  Nel pannello banca dati del Config, campo "Utilizzo minimo" in
  secondi. La colonna "Util.Min." nell'elenco banche mostra il valore
  impostato.

Come funziona:
  - Se l'utilizzo effettivo in montaggio e INFERIORE al minimo, il
    costo viene calcolato sul minimo impostato
  - Superata la soglia, il calcolo torna sull'utilizzo effettivo
  - Si applica ai modelli temporali (Al secondo, Al minuto,
    A blocchi); viene ignorato per "A clip" e "Forfait"

Dove si vede:
  Nel CSV e nell'XLSX di preventivo, colonna "Secondi Scoperti":
  mostra il minimo richiesto, i secondi effettivamente usati e la
  differenza non coperta. Serve a capire a prima vista dove stai
  pagando piu di quanto usi, e quindi dove conviene allungare
  l'inquadratura o cambiare archivio.


FILE DI LOG (v1.2.12+)
-----------------------
Tutti e tre gli script scrivono un registro delle operazioni in un
unico file. Serve soprattutto a te in caso di problemi: allegandolo a
una segnalazione, si capisce cosa e successo senza doverlo ricostruire
a memoria.

Dove si trova:
  macOS  : ~/Library/Logs/RepertoireDB/repertoire_db.log
  Windows: %LOCALAPPDATA%\Blackmagic Design\DaVinci Resolve\
            Logs\RepertoireDB\repertoire_db.log

Cosa contiene: data e ora, livello (INFO, WARNING, ERROR), nome dello
script e descrizione dell'operazione — timeline aperta, numero di clip
trovate, totale calcolato, esportazioni, errori.

Il file si ruota da solo quando supera i 5 MB: il contenuto vecchio
viene rinominato con estensione .old e si riparte da zero. Non cresce
all'infinito e non va svuotato a mano.

Nessun dato esce dal tuo computer: il log e un file di testo locale.


==================================================================
NOTA IMPORTANTE — TRANSIZIONI (DISSOLVE, FADE)
==================================================================

Il Calculator calcola la durata sorgente di ogni clip basandosi
sull'API nativa di DaVinci Resolve (GetSourceStartFrame /
GetSourceEndFrame), che restituisce i frame del segmento nella
timeline ESCLUDENDO i frame aggiuntivi usati dalle transizioni.

CLIP IN CROSS DISSOLVE — NON CALCOLATE CORRETTAMENTE:

  Quando due clip di archivio sono collegate da un cross dissolve
  (dissolvenza incrociata), entrambe utilizzano frame sorgente
  aggiuntivi che si sovrappongono nella zona di transizione.
  Questi frame extra NON vengono inclusi nel calcolo dei costi.

  Questo e una limitazione dell'API di DaVinci Resolve:
  non esiste un metodo di scripting per accedere agli oggetti
  "Transizione" su una timeline. Il problema non e risolvibile
  allo stato attuale delle API Blackmagic.

RACCOMANDAZIONE — COME GESTIRE LE DISSOLVE CON IL MATERIALE DI ARCHIVIO:

  Per evitare il problema del mancato calcolo dei frame in dissolvenza,
  adotta le seguenti pratiche nel montaggio:

  1. USA SOLO DISSOLVENZE "TO END" E "TO START"
     invece del cross dissolve tra due clip di archivio:

       - TO END   (Fade to Black alla fine della clip)
                  Usa solo i frame di coda della clip stessa.
                  Il materiale aggiuntivo rimane dentro i boundary
                  del segmento e viene calcolato correttamente.

       - TO START (Fade from Black all'inizio della clip)
                  Idem: usa solo i frame di testa della stessa clip.

     In questo modo ogni clip usa solo i propri frame e il calcolo
     e sempre corretto.

  2. SE VUOI INCROCIARE DUE CLIP DI ARCHIVIO (cross dissolve):
     Metti le due clip su due tracce video separate e sovrapponi
     manualmente il tratto di dissolve usando keyframe di opacita.
     In questo modo ogni clip conta solo i propri frame sulla
     propria traccia, senza che l'API li escluda.

     Esempio:
       Traccia V1: [Clip A ————————|fade out]
       Traccia V2:         [fade in|Clip B ————————]
                           ^^^^^^^
                           zona sovrapposta calcolata su entrambe

  3. APPROSSIMAZIONE RAPIDA (solo se non puoi evitare il cross dissolve):
     Una dissolve standard di 25 frame a 25fps usa circa 12-13 frame
     extra per ogni clip. Aggiungili manualmente nel CSV esportato.

Questo e un limite tecnico noto, non una dimenticanza.


==================================================================
CALCOLO COSTO — LOGICA DI ARROTONDAMENTO
==================================================================

Il calcolo segue tre livelli:

  1. Per singola clip / segmento  (valore informativo, proporzionale)
     Costo = durata_unica_secondi x (tariffa / unita)
     Nessun arrotondamento. Riflette il peso relativo di ogni clip.

  2. Per banca dati  (valore fatturato effettivo)
     Si sommano prima tutte le durate uniche della banca, poi si
     applica UN SOLO arrotondamento al secondo/minuto/blocco successivo.
     Es.: due clip da 30s ciascuna = 60s totali = 1 minuto fatturato,
     NON 1+1 = 2 minuti.

  3. Sconti
     Applicati sul valore fatturato aggregato per banca, dopo
     l'arrotondamento.

Se la somma proporzionale delle clip differisce dal valore fatturato
per effetto dell'arrotondamento, il riepilogo mostra la dicitura:

  ARROTONDATO A X minuti  (proporzionale EUR X.XX -> fatturato EUR X.XX)


==================================================================
SCONTI
==================================================================

Ogni banca dati puo avere uno o piu scaglioni di sconto.
Viene applicato lo scaglione con la soglia piu alta superata
(non si sommano piu scaglioni).

Tipi di sconto:

  flat         — la percentuale si applica sull'intero importo
                 della banca se la durata totale supera la soglia.
                 Es.: 15% su tutto se tot > 180s

  progressivo  — la percentuale si applica solo sulla parte di
                 durata eccedente la soglia; la parte entro la
                 soglia e fatturata a tariffa piena.

Aggiunta sconti nel Config:
  Imposta Soglia (sec), Sconto %, Tipo e clicca "+ Aggiungi".
  La banca viene salvata automaticamente con lo sconto.

Nel CSV di importazione i valori non sono case-sensitive:
"flat", "Flat", "FLAT" sono equivalenti; qualsiasi stringa
che contenga "prog" viene trattata come progressivo.

Gli sconti si applicano solo alle banche Video (basate su durata).
Per Fotografie/Giornali il modello e "A clip"; gli sconti sono
tecnicamente supportati ma applicati sul costo totale.


==================================================================
FORMATO CSV PER IMPORTAZIONE E ESPORTAZIONE BANCHE DATI
==================================================================

Il CSV delle banche dati e bidirezionale: puo essere sia importato
che esportato tramite i pulsanti del Config. Il file esportato con
"Esporta CSV" e direttamente reimportabile con "Importa JSON/CSV..."
senza perdita di dati.

Separatore: virgola (,) oppure punto e virgola (;)
Decimali: punto (.)
Righe che iniziano con #: commenti (ignorate dall'import)
Prima riga non-commento: intestazione (ignorata dall'import)

Colonne obbligatorie (1-4):
  1  Nome           — nome della banca dati (univoco, case-sensitive)
  2  Modello        — vedi MODELLI DI PRICING
  3  Tariffa (EUR)  — tariffa in euro per unita del modello
  4  Durata blocco  — durata blocco in secondi (solo "A blocchi"), altrimenti vuoto

Colonne aggiuntive (5-6):
  5  Tipo           — "Video", "Fotografie" o "Giornali" (default: Video)
  6  Audio eccedente — "true" se il calcolo audio eccedente e abilitato per
                       questa banca, "false" altrimenti

Colonne sconti (ripetibili in gruppi di 3, numero illimitato):
  7+0  Soglia N (sec) — soglia di durata totale (secondi)
  7+1  Sconto N (%)   — percentuale di sconto
  7+2  Tipo N         — "flat" oppure "progressivo" (o "progressive")

Esempio riga con due sconti (valori di esempio, non tariffe reali):
  Archivio Esempio,Al minuto,3000.0000,,Video,false,180,15.0000,flat,360,25.0000,flat

Nota: il formato e compatibile in lettura anche con file CSV creati
con versioni precedenti alla 1.2.3 (colonne 5-6 assenti). Le banche
prive delle colonne 5-6 vengono importate con tipo "Video" e audio
eccedente disabilitato.


MODELLI DI PRICING
------------------
  A clip            — tariffa fissa per ogni file sorgente unico usato
                      in timeline (indipendente dal numero di segmenti)
                      Obbligatorio per Fotografie e Giornali.
  Al secondo        — tariffa x secondi sorgente, ceil al secondo successivo
  Al minuto         — tariffa x minuti sorgente, ceil al minuto successivo
  A blocchi (custom)— tariffa x numero di blocchi, ceil al blocco successivo
                      (durata blocco impostata in col. 4 del CSV)
  Forfait           — prezzo fisso per l'intera banca dati, indipendente
                      da numero di clip e durata (v1.2.8+). Disponibile
                      per Video, Fotografie e Giornali.
                      Tutti i segmenti della banca sono elencati con
                      costo "compreso nel forfait"; il prezzo compare nel
                      subtotale e nel totale generale. Le banche a forfait
                      non generano secondi inutilizzati ne note di
                      arrotondamento.


==================================================================
CALCOLO DURATA SORGENTE — DETTAGLI TECNICI
==================================================================

La durata sorgente di ogni segmento viene letta direttamente
dall'API nativa di DaVinci Resolve:

  GetSourceStartFrame()  — frame sorgente di inizio del segmento
  GetSourceEndFrame()    — frame sorgente di fine del segmento

Questi valori sono relativi al segmento nella timeline e coprono
correttamente tutti i casi:

  Normale           srcOut - srcIn (frame sorgente unici)
  Slow Motion       idem — la durata sorgente e inferiore alla TL
  Time Warp         idem — la durata sorgente e superiore alla TL
  Freeze Frame      GetStart == GetEnd -> viene conteggiato 1 frame
  Reverse           GetStart > GetEnd -> valori scambiati automaticamente

Per il display del TC assoluto nel CSV (colonne Src In / Src Out),
lo script aggiunge l'offset "Start TC" del file sorgente al frame
relativo del segmento, ottenendo il TC assoluto corretto.

Il calcolo e completamente indipendente da:
  - frame rate della timeline (supportati: 23.976, 24, 25, 29.97, 30,
    50, 59.94, 60 fps)
  - effetti di velocita (retime, speed ramp, slow motion, time warp)
  - inversione della clip (reverse)

Se le API non restituiscono valori (es. generator, titoli, media non
collegato), il segmento viene ignorato silenziosamente.


==================================================================
NOTE E LIMITAZIONI NOTE
==================================================================

- Keywords case-sensitive: "Getty Images" != "getty images".
  Usa sempre il pannello "Tagga Clip Selezionate" per evitare errori.

- Keyword multiple supportate (v1.2.4+): il campo Keywords puo contenere
  altre keyword non di repertorio (es. "RAI COM;Documentario"). Il
  Calculator identifica la banca dati anche in presenza di keyword
  aggiuntive. Il tagging aggiunge la keyword di repertorio senza
  sovrascrivere le altre. La rimozione agisce solo sulle keyword
  corrispondenti a banche configurate.

- Generator, titoli e clip non collegate al Media Pool non vengono
  considerati nel calcolo (ignorati silenziosamente).

- Il rilevamento Reverse e best-effort basato sugli offset di trim;
  su alcuni codec gli offset possono essere invertiti anche senza
  reverse, producendo un falso positivo. Il costo resta comunque
  corretto perche calcolato sulla durata sorgente reale.

- Transizioni (dissolve, fade): i frame aggiuntivi usati da un cross
  dissolve tra due clip di archivio NON vengono calcolati. Usa dissolve
  "TO END" / "TO START" oppure sovrapponi le clip su due tracce video
  separate. Vedi sezione "TRANSIZIONI" sopra per i dettagli.

- Il CSV di esportazione include BOM UTF-8 per compatibilita
  con Microsoft Excel e Apple Numbers.

- Il file repertoire_db.json e la fonte di verita per il Calculator.
  Se lo elimini, tutte le banche dati vengono perse. Fai backup
  periodici o esporta le banche dati tramite "Esporta CSV" nel Config.

- Le banche dati create prima della v1.1 senza il campo "mediaType"
  vengono trattate automaticamente come Video. Per assegnare
  Fotografie o Giornali, seleziona la banca nel Config e modifica il Tipo.

- Lo script non accede a internet e non invia dati di nessun tipo.

- Il CSV di preventivo (esportato dal Calculator) e distinto dal CSV
  delle banche dati (esportato/importato dal Config). Non sono
  intercambiabili.


==================================================================
SEGNALAZIONE BUG
==================================================================

Se riscontri un bug durante l'utilizzo di RepertoireDB, puoi
segnalarlo direttamente via email in tre modi:

1. BOTTONE "🐛 Riporta bug" NEGLI SCRIPT
   Ogni script (Calculator, Config, Monitor) ha un bottone
   "🐛 Riporta bug" nella finestra:

     - RepertoireDB_Calculator: basso destra
     - RepertoireDB_Config: basso destra
     - RepertoireDB_Monitor: basso centro

   Clicca il bottone per aprire automaticamente il client email
   (Mail su macOS, il programma di posta predefinito su Windows)
   con una segnalazione pre-compilata contenente:
     - Nome dello script
     - Numero di versione
     - Sistema operativo (macOS / Windows / Linux)
     - Versione di DaVinci Resolve in uso
     - Spazi da riempire: descrizione del problema, comportamento
       atteso, passaggi per riprodurlo

   AVVISO PRIVACY (v1.2.13+)
   Prima di compilare l'email viene mostrato un avviso che dichiara
   esattamente cosa contiene la segnalazione:

     Contiene:      versione OS e Resolve, versione dello script,
                    nomi delle tue timeline, data e ora delle
                    operazioni, costi calcolati
     NON contiene:  password, credenziali, chiavi di accesso,
                    indirizzi IP, dati finanziari personali

   L'email si apre nel tuo programma di posta e NON viene inviata
   automaticamente: puoi leggerla, modificarla e cancellare qualsiasi
   informazione prima di spedirla. Se i nomi delle timeline sono
   riservati, cancellali: la segnalazione resta utile.

   L'email viene inviata a: tomfilmeditor.tools@gmail.com
   Si apre contemporaneamente anche la pagina PayPal per le donazioni:
   e voluto, non e un errore. Chiudila se non ti interessa.

2. CONTATTI DIRETTI
   Email: tomfilmeditor.tools@gmail.com
   Includi nella segnalazione:
     - Versione di DaVinci Resolve (Workspace > About)
     - Sistema operativo (macOS / Windows / Linux)
     - Descrizione dettagliata del bug
     - Passaggi per riprodurre il problema
     - Allegati: screenshot, il file di log (vedi sezione FILE DI LOG)
       e, se utile, il backup di repertoire_db.json

   Il file di log e la cosa piu utile da allegare: contiene la
   sequenza esatta delle operazioni fino all'errore.

3. SUPPORTO E DONAZIONI
   RepertoireDB e un progetto open source gratuito.
   Se lo trovi utile, considera una donazione su PayPal:
   https://paypal.me/acoffeefortom


==================================================================
PER SVILUPPATORI
==================================================================

RepertoireDB e open source (licenza MIT). Contributi benvenuti.

STRUTTURA DEI FILE
------------------
  RepertoireDB_Calculator.lua
    Script principale. Contiene la UI del calcolatore, la logica
    di scansione timeline (scanTimeline), il calcolo dei costi
    (aggregateCosts), l'esportazione CSV del preventivo e il
    rilevamento retime.

  RepertoireDB_Config.lua
    Interfaccia di gestione banche dati. Legge/scrive repertoire_db.json
    e gestisce il tagging delle clip nel Media Pool. Supporta
    importazione e esportazione CSV delle banche dati con round-trip
    completo (inclusi sconti, tipo media, audio eccedente).

  RepertoireDB_Monitor.lua
    Finestra floating separata per monitorare le banche dati in uso
    in tempo reale senza aprire il Calculator completo.

  MODULI CONDIVISI (in Fusion/Modules/Lua, non nella cartella script)

  LogManager.lua
    Sistema di log condiviso dai tre script. Si richiama con
    require("LogManager") + LogManager:init(). Cinque livelli
    (DEBUG, INFO, WARNING, ERROR, CRITICAL), rotazione per dimensione
    a 5 MB, percorsi cross-platform. Utility getTail(n) e readAll()
    per il debug.
    Nota: Resolve usa Lua 5.1 — verificare che le funzioni di libreria
    usate esistano in quella versione.

  BugReportDialog.lua
    Finestra di segnalazione bug con avviso privacy. Si richiama con
    require("BugReportDialog"). Metodi: :show() mostra l'avviso e il
    testo, :sendEmail() apre il client di posta, :createButton()
    restituisce etichetta e azione pronte per la UI.

  repertoire_db.json
    Database delle banche dati. Formato JSON array, creato automaticamente
    al primo avvio di Config. Ogni elemento:
      { "name": "...", "model": "...", "rate": 0.0,
        "mediaType": "Video", "audioExcess": true|nil,
        "utilMin": 30|nil,
        "discounts": [ { "threshold_sec": 180, "pct": 15, "type": "flat" } ] }

    utilMin — utilizzo minimo fatturabile in secondi (v1.2.11+),
              assente se non impostato.

    ATTENZIONE SE PUBBLICHI IL CODICE: questo file contiene le tariffe
    reali che hai inserito. Non va caricato su un repository pubblico
    ne distribuito: va escluso dal pacchetto e, nei sistemi di
    versionamento, inserito in .gitignore dal primo salvataggio (una
    volta pubblicato resta nella cronologia anche se poi lo cancelli).

COME AGGIUNGERE UNA NUOVA BANCA DATI VIA CODICE
------------------------------------------------
Modifica il file repertoire_db.json aggiungendo un oggetto
alla lista. Esempio:

  {
    "name": "Nome Banca",
    "model": "Al minuto",
    "rate": 1200.0,
    "mediaType": "Video",
    "discounts": [
      { "threshold_sec": 180, "pct": 15, "type": "flat" }
    ]
  }

Riavvia Config per applicare le modifiche.

COME ESTENDERE IL CALCOLO COSTI
--------------------------------
La funzione centrale e aggregateCosts() in Calculator.lua.
Riceve la lista dei risultati da scanTimeline() e applica
la logica di arrotondamento e sconto per banca dati.

Per aggiungere un nuovo modello di pricing, aggiungi un ramo
nella funzione calcCostBase() / calcCostProportional() e aggiorna
il Config per mostrare il nuovo modello nel menu.

KEYWORD MULTIPLI — IMPLEMENTAZIONE
-------------------------------------
Il Config usa SetMetadata("Keywords", ...) con piu valori separati
da punto e virgola. In BtnApplica: legge le keyword esistenti, rimuove
solo quelle che corrispondono a banche configurate (dbNameSet), aggiunge
la nuova keyword di repertorio, riscrive il campo. In BtnClearKw:
rimuove solo le keyword di repertorio, lascia invariate le altre.

Il Calculator (scanTimeline) legge il campo Keywords e divide per
";", "," o "\n", cercando il primo token che corrisponde a una banca
in dbMap. Se trovato, usa quello; altrimenti ignora silenziosamente
il clip.

TESTING
-------
La cartella Templates/ contiene file CSV di esempio che
rappresentano casi reali di timeline con retime, slow motion
e clip ripetute. Sono utili per verificare il comportamento
del calcolatore dopo modifiche.

SEGNALAZIONI E CONTRIBUTI
--------------------------
Apri una issue o una pull request sul repository del progetto.
Includi sempre la versione di DaVinci Resolve e il sistema
operativo quando segnali un problema.

Per donazioni volontarie: https://paypal.me/acoffeefortom


==================================================================
CHANGELOG
==================================================================

Cronologia completa e dettagliata: CHANGELOG.md nella cartella degli
script. Qui le novita in sintesi.

v1.2.14 (2026-10-26)
  - Le segnalazioni bug vanno al nuovo indirizzo dedicato
    tomfilmeditor.tools@gmail.com. Cambia solo il destinatario: il
    pulsante 🐛 funziona esattamente come prima
  - Il pacchetto non contiene piu il file con le tariffe precompilate:
    al suo posto c'e Templates/RepertoireDB_Archivi_template.csv, con
    gli stessi archivi e le tariffe da compilare. Le tariffe di ogni
    archivio si negoziano per progetto, non esiste un listino valido
    per tutti

v1.2.13 (2026-08-06)
  - Segnalazione bug con AVVISO PRIVACY: prima di compilare l'email
    viene dichiarato cosa contiene e cosa non contiene la segnalazione.
    L'email non parte da sola: la puoi leggere e modificare
  - Nuovo modulo condiviso BugReportDialog.lua (va in Fusion/Modules/Lua)
  - FIX: la colonna "Secondi Scoperti" (utilizzo minimo) mancava
    nell'esportazione CSV, mentre era presente in quella Excel

v1.2.12 (2026-08-06)
  - FILE DI LOG unico per tutti e tre gli script, con rotazione
    automatica a 5 MB (vedi sezione FILE DI LOG)
  - Nuovo modulo condiviso LogManager.lua (va in Fusion/Modules/Lua)
  - ATTENZIONE INSTALLAZIONE: da questa versione i due moduli
    condivisi vanno in una cartella DIVERSA da quella degli script

v1.2.11 (2026-08-06)
  - UTILIZZO MINIMO per banca dati: se usi meno del minimo fatturabile
    dell'archivio, il costo viene calcolato sul minimo. Nuova colonna
    "Util.Min." nell'elenco banche e "Secondi Scoperti" nei preventivi

v1.2.10 (2026-07-31)
  - Esportazione Excel a TRE FOGLI collegati da formule (Config,
    Segmenti, Riepilogo): cambiando una tariffa nel foglio Config si
    aggiorna tutto il preventivo senza rilanciare lo script
  - Clip duplicate evidenziate in arancio e contate a costo zero

v1.2.9 (2026-07-31)
  - Tab "Memorie" nel Config: salva e richiama configurazioni complete,
    con ripristino della precedente (vedi sezione TAB "MEMORIE")
  - Bottoni 📖 Guida / ☕ Caffe / 🐛 Bug uniformati su tutti gli script
  - Ordinamento per colonna nei risultati del Calculator

v1.2.8 (2026-07-30)
  - Nuovo modello di pricing FORFAIT: prezzo fisso per l'intera banca,
    indipendente da numero di clip e durata

v1.2.7
  - Nessuna voce documentata: non risulta ne in CHANGELOG.md ne qui.
    Probabilmente un numero mai rilasciato (salto di numerazione fra
    la 1.2.6 e la 1.2.8).

v1.2.6 (2026-07-25)
  - FIX: "Errore scrittura file" su macOS Sonoma con Resolve 20/21:
    il rilevamento del sistema operativo in getConfigPath() usava
    io.open() su una directory, che in Lua embedded di Resolve 20/21
    su Sonoma restituisce NIL → lo script sceglieva il path Linux
    (non esistente su macOS) → scrittura JSON fallita.
    Fix: rilevamento OS tramite uname -s, sempre affidabile.
  - FIX: aggiunto mkdir -p prima di ogni scrittura JSON (difensivo:
    evita errori se la directory viene rimossa o non esiste)
  - Installer: verifica e crea automaticamente la directory config
    e il JSON vuoto se assenti; mostra stato scrittura all'avvio
  - Config: versione allineata a 1.2.6

v1.2.5 (2026-07-24)
  - Monitor: clic su una banca seleziona automaticamente tutti i
    clip della banca in timeline tramite il menu nativo di Resolve
    (Timeline > Select Clips > By Flag Color)
  - Monitor: ogni banca riceve un flag con colore univoco e
    deterministico; se le banche superano i 16 colori disponibili
    le banche eccedenti ricevono 2 flag simultanei
  - Monitor: navigazione automatica del playhead al primo clip
    della banca al momento della selezione
  - Monitor: rimosso il cambio colore clip (clip color); solo flag
  - Monitor: i flag vengono rimossi al cambio banca e alla chiusura
  - Calculator: CSV ristrutturato — ordine sezioni: A) subtotali
    banche per categoria, B) subtotali categoria Video/Foto/Giornali,
    C) totale generale, D) banche con costo da definire, E) dettaglio
    segmenti
  - Calculator: aggiunta colonna "Rec TC In" e "Rec TC Out" (timecode
    record della timeline per ogni segmento, solo verifica)
  - Calculator: aggiunta colonna "Durata Montato" (durata del
    segmento nella timeline, utile per verificare discrepanze su
    clip con timewarp o freeze frame)
  - Calculator: dialogo pre-esportazione per scegliere l'ordinamento
    della sezione E (ordine di montaggio o per banca dati)
  - Installer: nuovo script RepertoireDB_Installer.lua che verifica
    Python 3 e openpyxl nei percorsi visibili da Resolve, installa
    openpyxl automaticamente con un click, e guida l'utente al
    download di Python se non presente
  - Calculator: esportazione XLSX (richiede Python 3 + openpyxl):
    Foglio 1 "Riepilogo" con subtotali per banca e totale evidenziati;
    Foglio 2 "Segmenti" con AutoFilter su tutte le colonne e colonna
    "Audio Eccedente" per filtro rapido; righe bloccate per header

v1.2.4 (2026-06-26)
  - FIX Config: il tagging non sovrascrive piu le keyword non di
    repertorio gia presenti nel campo Keywords delle clip
  - FIX Config: "Rimuovi keyword" rimuove solo le keyword di
    repertorio, lasciando invariate le altre keyword delle clip
  - FIX Calculator: riconosce le clip di repertorio anche quando
    il campo Keywords contiene altre keyword oltre al nome della banca
    (separatori supportati: ; , e a capo)
  - FIX Monitor: stessa correzione multi-keyword del Calculator;
    crash su timeline complesse risolto (rate nil su banche
    Fotografie/Giornali senza tariffa configurata)
  - Monitor: versione allineata a 1.2.4

v1.2.3 (2026-06-25)
  - Config: esportazione CSV banche dati con round-trip completo
    (reimportabile senza perdita di dati: nome, modello, tariffa,
    tipo media, audio eccedente, tutti gli sconti)
  - importFromCSV aggiornato per leggere le colonne Tipo e Audio
    eccedente (colonne 5-6 del nuovo formato)
  - Versione allineata tra Config e Calculator

v1.2.2 (2026-06-19 circa)
  - Calcolo audio eccedente configurabile per singola banca
    (checkbox "Calcola audio eccedente" nel Config, non piu globale)
  - FIX: tasto "Esporta CSV" nel Calculator restava disabilitato
    quando una banca senza tariffa definita era presente in timeline
  - FIX: colonna "Inutilizzati" spostata ai subtotali di banca nel
    riepilogo (non piu nelle singole clip)
  - CSV preventivo: rimossa colonna Transizione; nota arrotondamento
    spostata in colonna I (Note); riga avviso approssimazione in
    prima riga; costo segmento nascosto per modelli Al minuto e A blocchi
  - Config: aggiunta colonna "Audio Ecc." nell'elenco banche

v1.2.1
  - Sezione FOTOGRAFIE e GIORNALI nel Monitor (checkbox on/off)
  - Supporto banche Fotografie e Giornali nel Calculator e Config
  - Deduplicazione per-file su banche A clip

v1.2.0
  - Prima release pubblica
  - Modelli Al minuto, Al secondo, A blocchi, A clip
  - Sconti flat e progressivi
  - Esportazione CSV preventivo
  - Rilevamento retime (Slow Motion, Time Warp, Freeze Frame, Reverse)
  - Deduplicazione frame ripetuti
  - Monitor floating
==================================================================
