#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Traduzione inglese dell'interfaccia di RepertoireDB.

La chiave è il testo italiano esattamente come compare dentro T("...") nel
codice Lua, comprese le sequenze di escape (\\" e \\n) e gli spazi iniziali e
finali, che servono ad allineare le colonne a video.

GLOSSARIO FISSO — scelto una volta e usato sempre, per non avere la stessa
cosa chiamata in due modi in due finestre:

    banca dati / banca    -> archive          (come nei README pubblicati)
    banche (conteggio)    -> archives
    repertorio            -> archive footage
    tariffa               -> rate
    modello pricing       -> pricing model
    utilizzo minimo       -> minimum usage
    sconto                -> discount
    soglia                -> threshold
    audio eccedente       -> excess audio
    inutilizzati          -> unused
    dettaglio             -> breakdown
    riepilogo             -> summary
    arrotondato a         -> rounded up to
    proporzionale         -> pro rata
    fatturato             -> billed
    ripetuto              -> repeated
    segmento              -> segment
    configurazione (salvata) -> configuration

Note di stile: si usano i puntini di sospensione singoli (…) dove li usa
l'italiano, le maiuscole nei titoli di colonna seguono l'uso inglese
(sentence case, non Title Case), e i simboli (✓ ⚠ ✕ ▶ ↩ ↺ ↳ ▸ →) restano
dove sono.
"""

EN = {
    # ── Config — finestra "Tagga Clip Selezionate" ───────────────────────
    "Tagga Clip Selezionate": "Tag selected clips",
    "Seleziona le clip nel Media Pool, poi clicca Applica.":
        "Select the clips in the Media Pool, then click Apply.",
    "✓  Applica": "✓  Apply",
    "✕  Rimuovi keyword": "✕  Remove keywords",
    "Chiudi": "Close",
    "⚠  Nessuna clip selezionata nel Media Pool.":
        "⚠  No clips selected in the Media Pool.",
    "%d clip selezionate — scegli la banca dati e clicca Applica.":
        "%d clips selected — choose the archive and click Apply.",
    '✓  %d clip → \\"%s\\"': '✓  %d clips → \\"%s\\"',
    "  ⚠ %d file video ignorato: %s": "  ⚠ %d video file skipped: %s",
    "  ⚠ %d file video ignorati: %s": "  ⚠ %d video files skipped: %s",
    "✓  Keyword repertorio rimosse da %d clip  — seleziona il prossimo gruppo.":
        "✓  Archive keywords removed from %d clips  — select the next group.",

    # ── Config — durate ──────────────────────────────────────────────────
    "%dm %02ds": "%dm %02ds",
    "%ds": "%ds",

    # ── Config — testata ─────────────────────────────────────────────────
    "RepertoireDB v%s — Configurazione  |  © Tommaso Feraboli Film Editor":
        "RepertoireDB v%s — Configuration  |  © Tommaso Feraboli Film Editor",
    "RepertoireDB v": "RepertoireDB v",
    "Lingua:": "Language:",
    "Lingua dell'interfaccia. Con Automatico segue la lingua del sistema operativo, non quella di DaVinci Resolve: sono due impostazioni diverse.":
        "Interface language. On Automatic it follows your operating system's "
        "language, not DaVinci Resolve's: they are two different settings.",
    "Valuta:": "Currency:",
    "Cambia solo il simbolo mostrato. Gli importi non vengono convertiti.":
        "Changes only the symbol shown. Amounts are not converted.",
    "© Tommaso Feraboli Film Editor": "© Tommaso Feraboli Film Editor",
    "MIT License": "MIT License",

    # ── Config — ricerca e pulsanti elenco ───────────────────────────────
    "Cerca per nome o tipo media": "Search by name or media type",
    "Cerca banca…": "Search archives…",
    "+ Nuova": "+ New",
    "✎ Modifica": "✎ Edit",
    "Elimina": "Delete",
    "Importa JSON/CSV…": "Import JSON/CSV…",
    "Esporta CSV": "Export CSV",

    # ── Config — scheda della banca dati ─────────────────────────────────
    "Nome banca dati:": "Archive name:",
    "Inserisci nome nuova banca": "New archive name",
    "Tipo media:": "Media type:",
    "Modello pricing:": "Pricing model:",
    "Durata blocco (sec):": "Block length (sec):",
    "Utilizzo minimo (sec):": "Minimum usage (sec):",
    "(0 = nessun minimo — si fattura almeno questo utilizzo anche se l'effettivo è inferiore)":
        "(0 = no minimum — otherwise these seconds are billed even if you use fewer)",
    "Tariffa (%s):": "Rate (%s):",
    "es. 5300.00": "e.g. 5300.00",
    "(per unità del modello scelto)   ": "(per billing unit)   ",
    "Tariffa da definire": "Rate to be agreed",
    "Calcola audio eccedente": "Bill excess audio",
    "Se attivo, i secondi audio senza copertura video vengono fatturati al 50% della tariffa":
        "When on, audio seconds with no video coverage are billed at 50% of the rate",
    "── Sconti ─────────────────────────────────────────────────────":
        "── Discounts ──────────────────────────────────────────────────",
    "Soglia (sec):": "Threshold (sec):",
    "Sconto %:": "Discount %:",
    "Tipo:": "Type:",
    "+ Aggiungi sconto": "+ Add discount",
    "Salva modifiche": "Save changes",
    "Annulla": "Cancel",
    "⏭️  Apri Calcolatore": "⏭️  Open Calculator",

    # ── Config — tre pulsanti standard ───────────────────────────────────
    "Apre il file README": "Opens the README file",
    "Guida": "Help",
    "Supporta il progetto su PayPal": "Opens PayPal to support the project",
    "Offrimi un caffè": "Buy me a coffee",
    "Invia una segnalazione bug a tomfilmeditor.tools@gmail.com":
        "Opens a pre-filled bug report to tomfilmeditor.tools@gmail.com",
    "Riporta bug": "Report a bug",

    # ── Config — scheda Memorie ──────────────────────────────────────────
    "Configurazioni salvate:": "Saved configurations:",
    "↩  Ripristina precedente": "↩  Restore previous",
    "Ripristina la configurazione precedente all'ultimo caricamento":
        "Restores the configuration as it was before the last load",
    "Nome:": "Name:",
    "Nome configurazione…": "Configuration name…",
    "💾  Salva configurazione attuale": "💾  Save current configuration",
    "📂  Carica selezionata": "📂  Load selected",
    "🗑  Elimina selezionata": "🗑  Delete selected",

    # ── Config — intestazioni di colonna ─────────────────────────────────
    "Soglia": "Threshold",
    "Sconto %": "Discount %",
    "Tipo": "Type",
    "Oltre %s clip": "Over %s clips",
    "Oltre ": "Over ",
    "Nome": "Name",
    "Modello": "Model",
    "Blocco": "Block",
    "Util.Min.": "Min. use",
    "Tariffa ": "Rate ",
    "Sconti": "Discounts",
    "Audio Ecc.": "Exc. audio",
    "Salvata il": "Saved on",
    "Banche": "Archives",

    # ── Config — messaggi di stato ───────────────────────────────────────
    "Modifica abilitata — premi Salva per confermare.":
        "Editing enabled — press Save to confirm.",
    "Lingua interfaccia: %s": "Interface language: %s",
    "Lingua interfaccia: %s  (automatica, dal sistema)":
        "Interface language: %s  (automatic, from the system)",
    "Valuta cambiata": "Currency changed",
    "Valuta impostata: ": "Currency set to: ",
    "Cambia solo il simbolo mostrato accanto agli importi. Le cifre che hai inserito NON vengono convertite: restano i numeri che hai scritto tu.":
        "This changes only the symbol shown next to the amounts. The figures you "
        "entered are NOT converted: they stay the numbers you typed.",
    "Le finestre già aperte (Calculator, Monitor) mostrano il simbolo nuovo dopo essere state riaperte.":
        "Already-open windows (Calculator, Monitor) show the new symbol after "
        "you reopen them.",
    "Ho capito": "OK",
    "Eliminata.": "Deleted.",
    "⚠ Seleziona prima una voce dalla lista.":
        "⚠ Select an entry from the list first.",
    "⚠ Inserisci un nome.": "⚠ Enter a name.",
    "⚠ Tariffa non valida (usa il punto come decimale).":
        "⚠ Invalid rate (use a dot for decimals).",
    "⚠ Nome già esistente.": "⚠ That name is already in use.",
    "⚠ Soglia già presente.": "⚠ That threshold already exists.",
    "⚠ Seleziona uno sconto dalla lista.": "⚠ Select a discount from the list.",
    "⚠ Errore interno (vedi Console Resolve)":
        "⚠ Internal error (see the Resolve Console)",
    "⚠ Formato non supportato (usa .json o .csv)":
        "⚠ Unsupported format (use .json or .csv)",

    # ── Config — importazione ed esportazione ────────────────────────────
    "Modalità importazione": "Import mode",
    "Come vuoi importare le %d banche dati?":
        "How do you want to import these %d archives?",
    "Aggiungi nuove (salta duplicati)": "Add new (skip duplicates)",
    "Aggiorna esistenti (sovrascrive duplicati)":
        "Update existing (overwrite duplicates)",
    "Sostituisci tutto (cancella e reimporta)":
        "Replace all (clear and re-import)",
    "✓ Aggiunte: %d  Aggiornate: %d  Totale DB: %d":
        "✓ Added: %d  Updated: %d  Total in DB: %d",
    "⚠ Nessuna banca dati da esportare.": "⚠ There are no archives to export.",
    "⚠ Impossibile scrivere in: ": "⚠ Cannot write to: ",
    "✓ CSV esportato: ": "✓ CSV exported: ",
    "⚠ Nessuna banca dati configurata.": "⚠ No archives configured.",
    "⚠ Inserisci un nome per la configurazione.":
        "⚠ Enter a name for the configuration.",
    '✓ Configurazione \\"%s\\" salvata  (%d banche).':
        '✓ Configuration \\"%s\\" saved  (%d archives).',
    "⚠ Errore: ": "⚠ Error: ",
    "⚠ Seleziona una configurazione dalla lista.":
        "⚠ Select a configuration from the list.",
    "Carica configurazione": "Load configuration",
    "Caricando  \\\"%s\\\"\\nl'attuale configurazione verrà persa.\\n\\nProcedere?":
        "Loading  \\\"%s\\\"\\nwill discard the current configuration.\\n\\nContinue?",
    "Carica": "Load",
    "⚠ Errore caricamento: ": "⚠ Load failed: ",
    '✓ Configurazione \\"%s\\" caricata  (%d banche).':
        '✓ Configuration \\"%s\\" loaded  (%d archives).',
    'Eliminata: \\"%s\\"': 'Deleted: \\"%s\\"',
    "⚠ Nessun backup precedente trovato.": "⚠ No previous backup found.",
    "✓ Configurazione precedente ripristinata  (%d banche).":
        "✓ Previous configuration restored  (%d archives).",

    # ── Calculator — note di arrotondamento ──────────────────────────────
    "ARROTONDATO A %d secondo": "ROUNDED UP TO %d second",
    "ARROTONDATO A %d secondi": "ROUNDED UP TO %d seconds",
    "ARROTONDATO A %d minuto": "ROUNDED UP TO %d minute",
    "ARROTONDATO A %d minuti": "ROUNDED UP TO %d minutes",
    "ARROTONDATO A %d blocco da %ds": "ROUNDED UP TO %d block of %ds",
    "ARROTONDATO A %d blocchi da %ds": "ROUNDED UP TO %d blocks of %ds",

    # ── Calculator — note di sconto ──────────────────────────────────────
    "Sconto flat %d%% (oltre %s) = -%s": "Flat discount %d%% (over %s) = -%s",
    "Sconto prog %d%% su %ds eccedenti (oltre %s) = -%s":
        "Tiered discount %d%% on %ds of excess (over %s) = -%s",
    "Sconto prog %d%% su %dmin eccedenti (oltre %s) = -%s":
        "Tiered discount %d%% on %dmin of excess (over %s) = -%s",
    "Sconto prog %d%% su %d blocchi eccedenti (oltre %s) = -%s":
        "Tiered discount %d%% on %d excess blocks (over %s) = -%s",
    "Sconto %d%% (oltre %s) = -%s": "Discount %d%% (over %s) = -%s",

    # ── Calculator — note di retiming ────────────────────────────────────
    "Reverse + Time Warp %d%%": "Reverse + Time Warp %d%%",
    "Reverse + Slow Motion %d%%": "Reverse + Slow Motion %d%%",
    "Time Warp %d%%": "Time Warp %d%%",
    "Slow Motion %d%%": "Slow Motion %d%%",

    # ── Calculator — note di calcolo ─────────────────────────────────────
    "%s  (proporzionale %s → fatturato %s)": "%s  (pro rata %s → billed %s)",
    "⚠ %d sec inutilizzati → %s extra": "⚠ %d unused sec → %s extra",
    "⚠ RIPETUTO — %s già conteggiati (src %s→%s)":
        "⚠ REUSED — %s already counted (src %s→%s)",
    "⚠ PARZIALMENTE RIPETUTO — %d frame unici su %d (src %s→%s)":
        "⚠ PARTLY REUSED — %d unique frames out of %d (src %s→%s)",
    "⚠ %ds inut. →%s": "⚠ %ds unused →%s",
    "⚠ parziale — %s unici su %s": "⚠ partial — %s unique out of %s",
    "    ↳ uso %d/%d": "    ↳ used %d/%d",

    # ── Calculator — testata e comandi ───────────────────────────────────
    "RepertoireDB v%s — Calcolatore Costi Repertorio  |  © Tommaso Feraboli Film Editor":
        "RepertoireDB v%s — Archive Footage Cost Calculator  |  © Tommaso Feraboli Film Editor",
    "Licenza MIT": "MIT License",
    "Timeline:": "Timeline:",
    "Ordinamento:": "Sort by:",
    "▶  CALCOLA": "▶  CALCULATE",
    "Totale: —": "Total: —",
    "Esporta CSV / XLSX": "Export CSV / XLSX",

    # ── Calculator — colonne dei risultati ───────────────────────────────
    "File sorgente": "Source file",
    "Banca dati": "Archive",
    "TL In": "TL In",
    "TL Out": "TL Out",
    "Costo ": "Cost ",
    "Dettaglio": "Breakdown",
    "Inutilizzati": "Unused",

    # ── Calculator — riepilogo ───────────────────────────────────────────
    "RIEPILOGO": "SUMMARY",
    "    Subtotale ": "    Subtotal ",
    "  ▸ AUDIO ECCEDENTE": "  ▸ EXCESS AUDIO",
    "    Subtotale Audio Eccedente": "    Excess audio subtotal",
    "  TOTALE GENERALE": "  GRAND TOTAL",
    "  ⚠ Ancora da definire i costi di: ": "  ⚠ Costs still to be agreed for: ",
    "TOTALE: %s  (video %s + audio eccedente %s)  |  Durata video: %s":
        "TOTAL: %s  (video %s + excess audio %s)  |  Video duration: %s",
    "TOTALE: %s  |  Durata: %s": "TOTAL: %s  |  Duration: %s",

    # ── Calculator — messaggi ────────────────────────────────────────────
    "⚠ Nessuna banca dati configurata. Avvia prima RepertoireDB_Config.":
        "⚠ No archives configured. Run RepertoireDB_Config first.",
    "⚠ Nessuna timeline selezionata.": "⚠ No timeline selected.",
    "Analisi '%s' @ %.3f fps...": "Analyzing '%s' @ %.3f fps…",
    "Completato — %d clip sorgente trovate.": "Done — %d source clips found.",

    # ── Calculator — dialogo di esportazione ─────────────────────────────
    "Esporta — Opzioni": "Export options",
    "Formato:": "Format:",
    "Ordine sezione Segmenti:": "Segments order:",
    "Esporta…": "Export…",
    "Esportazione annullata.": "Export canceled.",
    "✓ CSV: ": "✓ CSV: ",
    "⚠ Impossibile scrivere file temporaneo in ":
        "⚠ Cannot write a temporary file in ",
    "✓ XLSX: ": "✓ XLSX: ",
    "⚠ openpyxl non installato — esegui: pip3 install openpyxl":
        "⚠ openpyxl is not installed — run: pip3 install openpyxl",
    "⚠ Errore Python: %s": "⚠ Python error: %s",
    "(nessun output)": "(no output)",
    "✓ README.txt aperto nel tuo editor di testo.":
        "✓ README.txt opened in your text editor.",
    "⚠ Impossibile aprire README.txt: ": "⚠ Cannot open README.txt: ",

    # ── Calculator — esportazione CSV del preventivo ─────────────────────
    # Il CSV è il file che si consegna al produttore: va tradotto per intero,
    # intestazioni comprese. Non va confuso con l'esportazione CSV del Config,
    # che resta in italiano perché è reimportabile.
    "DA DEFINIRE": "TO BE AGREED",
    "⚠ CALCOLO APPROSSIMATIVO — questo report non sostituisce il calcolo ufficiale della produzione. I costi sono indicativi e soggetti a variazioni contrattuali.":
        "⚠ WORKING ESTIMATE — this report does not replace the production's "
        "official costing. Figures are indicative and subject to contractual terms.",
    "Timeline: ": "Timeline: ",
    "Generato: ": "Generated: ",
    "Banca Dati,Costo Lordo %s,Somma Clip %s,Sconto,Costo Netto %s,Durata totale,Secondi Scoperti,Note":
        "Archive,Gross cost %s,Sum of clips %s,Discount,Net cost %s,Total duration,Shortfall,Notes",
    "Banca Dati,Costo Lordo %s,N. Clip,Sconto,Costo Netto %s,Note":
        "Archive,Gross cost %s,No. of clips,Discount,Net cost %s,Notes",
    "AUDIO ECCEDENTE": "EXCESS AUDIO",
    "Banca Dati,Durata Eccedente,Costo Audio %s,Note":
        "Archive,Excess duration,Audio cost %s,Notes",
    "BANCHE CON COSTO DA DEFINIRE (non incluse nel totale)":
        "ARCHIVES WITH RATES TO BE AGREED (not included in the total)",
    "Banca Dati,Nota": "Archive,Note",
    "DETTAGLIO SEGMENTI": "SEGMENT BREAKDOWN",
    "PER BANCA DATI": "BY ARCHIVE",
    "ORDINE DI MONTAGGIO": "EDIT ORDER",
    "File,Tipo,Banca Dati,Modello,Src In,Src Out,Durata Sorgente,Rec TC In,Rec TC Out,Durata Montato,Costo Segmento %s,Note":
        "File,Type,Archive,Model,Src In,Src Out,Source duration,Rec TC In,Rec TC Out,Edited duration,Segment cost %s,Notes",

    # ── Monitor ──────────────────────────────────────────────────────────
    "RepertoireDB v%s — Monitor": "RepertoireDB v%s — Monitor",
    "Clicca su una banca per selezionarne i segmenti in timeline":
        "Click an archive to select its segments in the timeline",
    "Mostra Fotografie e Giornali": "Show photos and newspapers",
    "↺  Aggiorna": "↺  Refresh",
    "Durata / Clip": "Dur. / Clips",
    "Seg. Video": "Video segs",
    "Seg. Audio": "Audio segs",
    "TOTALE VIDEO": "VIDEO TOTAL",
    "Totale ": "Total ",
    "%s  —  aggiornato %s": "%s  —  updated %s",
    "▶ %s [%s] — %d segmento": "▶ %s [%s] — %d segment",
    "▶ %s [%s] — %d segmenti": "▶ %s [%s] — %d segments",
}
