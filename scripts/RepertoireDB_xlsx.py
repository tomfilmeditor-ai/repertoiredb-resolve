#!/usr/bin/env python3
"""
RepertoireDB_xlsx.py  v1.2.11

Genera report XLSX a 3 fogli (Riepilogo / Segmenti / Config) con formule
cross-sheet collegate. Richiede: openpyxl >= 3.0

Autore: Tommaso Feraboli — Film Editor
Compatibile con DaVinci Resolve 19/20 (macOS e Windows)
"""

import sys
import json
from collections import defaultdict

try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
except ImportError:
    print("ERR:openpyxl non installato. Esegui: pip3 install openpyxl")
    sys.exit(2)

# ── Palette ──────────────────────────────────────────────────────────────────
C_HEADER  = "2E75B6"   # blu intestazioni sezione/colonne
C_SUB_RP  = "BDD7EE"   # azzurro subtotali Riepilogo
C_TOT     = "1F3864"   # blu scuro totale generale
C_ALT     = "F2F2F2"   # grigio righe alterne
C_WHITE   = "FFFFFF"
C_DEDUP   = "FCE4D6"   # arancio — clip deduplicate (costo statico)
C_HELP    = "DDDDDD"   # grigio helper nascosti
C_SEG_SUB = "E2EFDA"   # verde subtotali Segmenti

# Divisore verticale: thin right con colore = grigio alternato (F2F2F2)
# → invisibile su righe grigie, visibile su righe bianche
_VBORDER = Border(right=Side(style="thin", color=C_ALT))


def _fill(hex_color):
    return PatternFill(fill_type="solid", fgColor=hex_color)

def _font(bold=False, size=10, color="000000", name="Arial"):
    return Font(bold=bold, size=size, color=color, name=name)

# ── Etichette dei valori di dominio ──────────────────────────────────────────
# I valori nel JSON sono canonici ("A clip", "Al minuto", "Video"): sono le
# chiavi salvate nei database. Le etichette da scrivere nel foglio arrivano
# già risolte da Settings.lua, dentro data["labels"]: qui NON si tiene una
# seconda tabella di traduzioni, perché la stessa regola in due posti è quello
# che ha prodotto lo scarto fra foglio e motore del 30 ottobre.
#
# I valori di default sono quelli canonici, così un JSON prodotto da un
# Calculator più vecchio continua a funzionare come prima.
# Testo del foglio: intestazioni, titoli, note. Tradotto qui dentro e non
# ricevuto dal Calculator, perché queste frasi esistono soltanto nel foglio
# Excel e il Lua non le conosce. La chiave è l'italiano, come in Strings.lua.
#
# I NOMI DEI TRE FOGLI sono dentro ogni formula ("Config!$A$3"): tradurli
# significa tradurli anche là, ed è il motivo per cui stanno in LBL insieme
# alle altre etichette e non in questa tabella.
FOGLIO = {
    "en": {
        # nomi dei fogli
        "Riepilogo": "Summary",
        "Segmenti":  "Segments",
        "Config":    "Config",
        # foglio Config
        "FPS Progetto": "Project FPS",
        "← modifica qui il frame rate del progetto (es. 24, 25, 30)":
            "← change the project frame rate here (e.g. 24, 25, 30)",
        "Nome Banca":        "Archive name",
        "Tipo":              "Type",
        "Modello":           "Model",
        "Tariffa ":          "Rate ",
        "Blocco (sec)":      "Block (sec)",
        "Utilizzo\nMin. (sec)": "Minimum\nusage (sec)",
        "Note":              "Notes",
        "Soglia %d\n(min/clip)": "Threshold %d\n(min/clips)",
        "Sconto %d\n(%%)":       "Discount %d\n(%%)",
        # foglio Segmenti
        "File":              "File",
        "Banca Dati":        "Archive",
        "Src In":            "Src In",
        "Src Out":           "Src Out",
        "Durata Sorgente":   "Source duration",
        "Rec TC In":         "Rec TC In",
        "Rec TC Out":        "Rec TC Out",
        "Durata Montato":    "Edited duration",
        "Costo Segmento ":   "Segment cost ",
        "Audio Eccedente":   "Excess audio",
        "Subtotale: ":       "Subtotal: ",
        # foglio Riepilogo
        "Riepilogo costi repertorio": "Archive footage cost summary",
        "Timeline: ":        "Timeline: ",
        "Generato: ":        "Generated: ",
        "Costo Lordo ":      "Gross cost ",
        "Occorrenze":        "Billable clips",
        "Sconto %":          "Discount %",
        "Costo Netto ":      "Net cost ",
        "Durata totale":     "Total duration",
        "Secondi Scoperti":  "Shortfall",
        "Riusate":           "Reused",
        "SUBTOTALE ":        "SUBTOTAL ",
        "TOTALE GENERALE":   "GRAND TOTAL",
        "DA DEFINIRE": "TO BE AGREED",
        # legenda e note
        "Min %ds - Usati %ds - Scoperti %ds":
            "Min %ds - Used %ds - Shortfall %ds",
        "Legenda:  ":        "Key:  ",
        "D=Sconto % auto (soglie in Config H-Q: minuti per modelli temporali, clip per 'A clip') — sovrascrivibile manualmente":
            "D=automatic discount % (thresholds in Config H-Q: minutes for time-based models, clips for per-clip) — can be overwritten by hand",
        "F=Utilizzo Min.(sec): se > 0 il costo usa MAX(durata_reale, F)":
            "F=minimum usage (sec): when above 0 the cost uses MAX(actual duration, F)",
        "C=Occorrenze: solo le clip che si pagano":
            "C=billable clips: only the clips that are charged for",
        "I=Riusate: comparse non fatturate perché il materiale era già conteggiato (una ripetuta in parte resta fatturata per la sua parte nuova e non compare qui)":
            "I=reused: occurrences not billed because the material was already counted (one repeated only in part stays billable for its new frames and is not listed here)",
        "🟠 nel foglio Segmenti = materiale già conteggiato":
            "🟠 in the Segments sheet = material already counted",
    },
}


def _T(testo):
    """Traduce una frase del foglio. Se manca, resta l'italiano."""
    lingua = LBL.get("_lang", "it")
    if lingua == "it":
        return testo
    return (FOGLIO.get(lingua) or {}).get(testo, testo)


LBL = {
    "sh_cfg":   "Config",
    "tbd":      "DA DEFINIRE",
    "sh_seg":   "Segmenti",
    "m_clip":   "A clip",
    "m_second": "Al secondo",
    "m_minute": "Al minuto",
    "m_block":  "A blocchi (custom)",
    "m_flat":   "Forfait",
    "t_video":  "Video",
    "t_photo":  "Fotografie",
    "t_press":  "Giornali",
}
_CHIAVI = {
    "m_clip": "A clip", "m_second": "Al secondo", "m_minute": "Al minuto",
    "m_block": "A blocchi (custom)", "m_flat": "Forfait",
}
_CHIAVI_T = {"t_video": "Video", "t_photo": "Fotografie", "t_press": "Giornali"}


def carica_etichette(data):
    """Riempie LBL con le etichette spedite dal Calculator.

    Il testo scritto nelle celle e i letterali dentro le formule che lo
    confrontano escono da qui, quindi sono coerenti per costruzione: li
    scrive lo stesso programma nella stessa esecuzione.
    """
    lab = data.get("labels") or {}
    mod = lab.get("models") or {}
    med = lab.get("media") or {}
    LBL["_lang"] = lab.get("language") or "it"
    # I nomi dei fogli finiscono nelle formule: vanno presi dalla stessa
    # tabella del resto del testo, o le formule puntano a fogli inesistenti.
    LBL["sh_cfg"] = _T("Config")
    LBL["sh_seg"] = _T("Segmenti")
    # "DA DEFINIRE" lo scrivono le formule e lo confrontano altre formule:
    # deve essere la stessa parola in tutti i punti, o il confronto non trova
    # più niente e i subtotali includono righe senza tariffa.
    LBL["tbd"] = _T("DA DEFINIRE")
    for k, canon in _CHIAVI.items():
        LBL[k] = mod.get(canon) or canon
    for k, canon in _CHIAVI_T.items():
        LBL[k] = med.get(canon) or canon


def etichetta_modello(v):
    return (LBL.get("m_clip") if v == "A clip" else
            LBL.get("m_second") if v == "Al secondo" else
            LBL.get("m_minute") if v == "Al minuto" else
            LBL.get("m_block") if v == "A blocchi (custom)" else
            LBL.get("m_flat") if v == "Forfait" else (v or ""))


def etichetta_media(v):
    return {"Video": LBL["t_video"], "Fotografie": LBL["t_photo"],
            "Giornali": LBL["t_press"]}.get(v, v or "")


def money_fmt(symbol):
    """Formato numerico Excel con il simbolo della valuta davanti.

    Il simbolo sta nel formato e non nel valore: la cella resta un numero,
    le formule continuano a funzionare e il foglio non si rompe.
    """
    s = (symbol or "\u20ac").replace('"', "")
    return '"%s"#,##0.00' % s


def _a(cell, value=None, fill=None, font=None, align=None, num_fmt=None, vborder=False):
    if value is not None:
        cell.value = value
    if fill:
        cell.fill = fill
    if font:
        cell.font = font
    if align:
        cell.alignment = align
    if num_fmt:
        cell.number_format = num_fmt
    if vborder:
        cell.border = _VBORDER

def as_dict(val):
    return val if isinstance(val, dict) else {}

def fmt_eur(val):
    if val is None:
        return _T("DA DEFINIRE")
    try:
        return f"{float(val):.2f}"
    except Exception:
        return str(val)


# ─────────────────────────────────────────────────────────────────────────────
# SHEET 3 — Config
# ─────────────────────────────────────────────────────────────────────────────
#
# Colonne visibili A-Q:
#   A  Nome Banca
#   B  Tipo
#   C  Modello
#   D  Tariffa (valuta scelta)
#   E  Blocco (sec)
#   F  Utilizzo Min. (sec)  ← se > 0, costo calcolato su MAX(dur_effettiva, F)
#   G  Note
#   H  Soglia 1 (min/clip)   I  Sconto 1 (%)
#   J  Soglia 2              K  Sconto 2 (%)
#   L  Soglia 3              M  Sconto 3 (%)
#   N  Soglia 4              O  Sconto 4 (%)
#   P  Soglia 5              Q  Sconto 5 (%)
#
# Colonne nascoste R-V: conversione min→sec per soglie H,J,L,N,P
#   =IF(C{r}="A clip", soglia, soglia*60)
#
# Soglie in minuti per modelli temporali; in clip per "A clip".
# Soglia = 0 → tier disabilitato.

def _disc_headers():
    """Dieci intestazioni da due sole frasi tradotte, invece di dieci stringhe
    quasi identiche: così chi traduce scrive una volta e non cinque."""
    out = []
    for i in range(1, 6):
        out.append(_T("Soglia %d\n(min/clip)") % i)
        out.append(_T("Sconto %d\n(%%)") % i)
    return out


def write_config(ws, data):
    fps        = data.get("fps", 25)
    cur        = data.get("currencySymbol", "\u20ac")
    MF         = money_fmt(cur)
    db_entries = as_dict(data.get("dbEntryByName", {}))

    # F=Util.Min.(sec), G=Note, H-Q=soglie/sconti × 5
    widths = {"A":30,"B":12,"C":18,"D":12,"E":14,"F":14,
              "G":36,"H":12,"I":10,"J":12,"K":10,"L":12,"M":10,
              "N":12,"O":10,"P":12,"Q":10}
    for col, w in widths.items():
        ws.column_dimensions[col].width = w
    # Colonne R-V nascoste: conversione automatica min→sec (o clip invariati)
    for col in ["R","S","T","U","V"]:
        ws.column_dimensions[col].hidden = True
        ws.column_dimensions[col].width  = 10

    # Riga 1 — FPS
    ws["A1"] = _T("FPS Progetto")
    ws["A1"].font = _font(bold=True)
    ws["B1"] = fps
    ws["B1"].font = _font(bold=True, color="000080")
    ws["C1"] = _T("← modifica qui il frame rate del progetto (es. 24, 25, 30)")
    ws["C1"].font = _font(color="888888", size=9)

    # Riga 2 — intestazioni (A-G base + H-Q soglie × 5)
    base_hdrs = [_T("Nome Banca"), _T("Tipo"), _T("Modello"), _T("Tariffa ") + cur,
                 _T("Blocco (sec)"), _T("Utilizzo\nMin. (sec)"), _T("Note")]
    for c, h in enumerate(base_hdrs + _disc_headers(), 1):
        cell = ws.cell(2, c)
        _a(cell, h, fill=_fill(C_HEADER),
           font=_font(bold=True, size=9, color=C_WHITE),
           align=Alignment(horizontal="center", wrap_text=True))
    ws.row_dimensions[2].height = 30

    # Dati banche
    for i, (name, entry) in enumerate(sorted(db_entries.items())):
        r = i + 3
        row_fill = _fill(C_ALT) if i % 2 == 1 else _fill(C_WHITE)
        vals = [
            name,
            etichetta_media(entry.get("mediaType", "Video")),
            etichetta_modello(entry.get("model", "")),
            entry.get("rate", 0),
            entry.get("blockSec", "") if entry.get("blockSec") else "",
            entry.get("utilMin", "") if entry.get("utilMin") else "",
            entry.get("notes", ""),
        ]
        for c, v in enumerate(vals, 1):
            cell = ws.cell(r, c)
            _a(cell, v, fill=row_fill, vborder=True)
            if c == 4:
                cell.number_format = MF
            if c == 6:
                cell.number_format = '#,##0'

        # Soglie sconto H-Q (vuote, editabili dall'utente):
        # H(8)=soglia1, I(9)=sconto1, J(10)=soglia2, K(11)=sconto2,
        # L(12)=soglia3, M(13)=sconto3, N(14)=soglia4, O(15)=sconto4,
        # P(16)=soglia5, Q(17)=sconto5
        for c in range(8, 18):
            cell = ws.cell(r, c)
            _a(cell, fill=row_fill, vborder=True)
            if c % 2 == 1:  # sconti: I(9),K(11),M(13),O(15),Q(17) = dispari
                cell.number_format = '0.00'

        # Colonne nascoste R-V: converti min→sec per soglie H,J,L,N,P
        tier_input_cols = ["H", "J", "L", "N", "P"]
        hidden_cols     = ["R", "S", "T", "U", "V"]
        for inp, hid in zip(tier_input_cols, hidden_cols):
            ws[f"{hid}{r}"] = f'=IF(C{r}="{LBL["m_clip"]}",{inp}{r},{inp}{r}*60)'


# ─────────────────────────────────────────────────────────────────────────────
# SHEET 2 — Segmenti
# ─────────────────────────────────────────────────────────────────────────────

# Config range esteso a $G$202 per includere colonna F (Utilizzo Min.)
_K_FORMULA = (
    '=IFERROR(IF(VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_second}",'
    'CEILING(P{r}/{sh_cfg}!$B$1,1)*VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,4,0),'
    'IF(VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_clip}",'
    'IF(VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,4,0)=0,"{tbd}",'
    'VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,4,0)),"")),"")'
)
_TC_G = (
    '=IFERROR(TEXT(INT(P{r}/(60*{sh_cfg}!$B$1)),"00")&":"'
    '&TEXT(INT(MOD(P{r},60*{sh_cfg}!$B$1)/{sh_cfg}!$B$1),"00")&":"'
    '&TEXT(MOD(P{r},{sh_cfg}!$B$1),"00"),"")'
)
_TC_J = (
    '=IFERROR(TEXT(INT(S{r}/(60*{sh_cfg}!$B$1)),"00")&":"'
    '&TEXT(INT(MOD(S{r},60*{sh_cfg}!$B$1)/{sh_cfg}!$B$1),"00")&":"'
    '&TEXT(MOD(S{r},{sh_cfg}!$B$1),"00"),"")'
)
_N  = '=IFERROR(VALUE(LEFT(E{r},2))*3600*{sh_cfg}!$B$1+VALUE(MID(E{r},4,2))*60*{sh_cfg}!$B$1+VALUE(MID(E{r},7,2))*{sh_cfg}!$B$1+VALUE(RIGHT(E{r},2)),0)'
_O2 = '=IFERROR(VALUE(LEFT(F{r},2))*3600*{sh_cfg}!$B$1+VALUE(MID(F{r},4,2))*60*{sh_cfg}!$B$1+VALUE(MID(F{r},7,2))*{sh_cfg}!$B$1+VALUE(RIGHT(F{r},2)),0)'
_Q  = '=IFERROR(VALUE(LEFT(H{r},2))*3600*{sh_cfg}!$B$1+VALUE(MID(H{r},4,2))*60*{sh_cfg}!$B$1+VALUE(MID(H{r},7,2))*{sh_cfg}!$B$1+VALUE(RIGHT(H{r},2)),0)'
_R  = '=IFERROR(VALUE(LEFT(I{r},2))*3600*{sh_cfg}!$B$1+VALUE(MID(I{r},4,2))*60*{sh_cfg}!$B$1+VALUE(MID(I{r},7,2))*{sh_cfg}!$B$1+VALUE(RIGHT(I{r},2)),0)'


def _write_seg_row(ws, r, row, seg, row_fill, MF, seg_idx=0):
    sh_cfg   = LBL["sh_cfg"]          # nome del foglio Config, tradotto
    dup      = seg.get("dupStatus", "nuovo")
    is_dedup = dup in ("duplicato", "parziale")
    fill     = _fill(C_DEDUP) if is_dedup else row_fill

    # Un segmento "si paga" secondo il modello della banca:
    #  - "A clip": si paga la clip sorgente, una volta sola. Le comparse
    #    successive della stessa clip in timeline non si contano.
    #  - modelli a tempo: si pagano i fotogrammi non già conteggiati, quindi
    #    un segmento interamente ripetuto non vale, uno ripetuto in parte
    #    vale per la sua parte nuova (ci pensa frUnici, qui sotto).
    # Il valore viene dal campo strutturato che il motore trasmette, non dal
    # testo della nota: le diciture sono più di una e cambiano nel tempo.
    if row.get("model", "") == "A clip":
        billable = 1 if seg_idx == 0 else 0
    else:
        billable = 0 if dup == "duplicato" else 1

    static = {
        1: row.get("mediaName", ""),
        2: etichetta_media(row.get("mediaType", "Video")),
        3: row.get("dbName", ""),
        5: seg.get("srcIn", ""),
        6: seg.get("srcOut", ""),
        8: seg.get("tlIn", ""),
        9: seg.get("tlOut", ""),
        12: seg.get("note", ""),
    }
    for c, v in static.items():
        _a(ws.cell(r, c), v, fill=fill, vborder=True)

    _a(ws.cell(r, 4),  f'=IFERROR(VLOOKUP(C{r},{sh_cfg}!$A$3:$G$202,3,0),"")', fill=fill, vborder=True)
    _a(ws.cell(r, 7),  _TC_G.format(r=r, **LBL), fill=fill, vborder=True)
    _a(ws.cell(r, 10), _TC_J.format(r=r, **LBL), fill=fill, vborder=True)

    if is_dedup:
        _a(ws.cell(r, 11), 0, fill=fill, vborder=True, num_fmt=MF)
    else:
        _a(ws.cell(r, 11), _K_FORMULA.format(r=r, **LBL), fill=fill, vborder=True)

    _a(ws.cell(r, 13), "Sì" if row.get("dbName", "") in {} else "", fill=fill, vborder=True)

    # Helper N–S (nascoste, no vborder)
    ws.cell(r, 14).value = _N.format(r=r, **LBL)
    ws.cell(r, 15).value = _O2.format(r=r, **LBL)
    ws.cell(r, 16).value = f'=MAX(O{r}-N{r},0)'
    ws.cell(r, 17).value = _Q.format(r=r, **LBL)
    ws.cell(r, 18).value = _R.format(r=r, **LBL)
    ws.cell(r, 19).value = f'=MAX(R{r}-Q{r},0)'

    # Helper T–U (nascoste): le due quantità che il motore ha già misurato
    # sulla timeline e che il foglio non deve ricavarsi da solo.
    #   T = fotogrammi non già conteggiati (P tiene invece il totale del
    #       segmento, che resta giusto come durata della singola clip)
    #   U = 1 se il segmento si paga, 0 se è una ripetizione
    # Le righe di struttura (separatori, sottototali) non scrivono nulla qui:
    # così non vengono contate né fra quelle da pagare né fra i duplicati.
    # Se frUnici manca, il Calculator è più vecchio di questo generatore
    # (installazione a mano fatta a metà). In quel caso si torna al totale del
    # segmento, cioè al comportamento precedente: sovraconta i riusi, ma è uno
    # stato noto. Mettere zero darebbe durate nulle e costi stravolti in silenzio.
    fr_unici = seg.get("frUnici")
    ws.cell(r, 20).value = (int(fr_unici) if isinstance(fr_unici, (int, float))
                            else f'=MAX(O{r}-N{r},0)')
    ws.cell(r, 21).value = billable


def _write_sub_row(ws, r, label, bank):
    _a(ws.cell(r, 1), f"  → {label}", fill=_fill(C_SEG_SUB), font=_font(bold=True, size=9))
    _a(ws.cell(r, 3), bank,            fill=_fill(C_SEG_SUB), font=_font(bold=True, size=9))
    for c in [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]:
        ws.cell(r, c).fill = _fill(C_SEG_SUB)


def write_segmenti(ws, data):
    cur = data.get("currencySymbol", "\u20ac")
    MF  = money_fmt(cur)
    rows      = data.get("rows", [])
    excess    = as_dict(data.get("excessByDB", {}))
    sort_bank = data.get("sortByBank", False)

    vis_hdrs = [_T("File"), _T("Tipo"), _T("Banca Dati"), _T("Modello"),
                _T("Src In"), _T("Src Out"), _T("Durata Sorgente"),
                _T("Rec TC In"), _T("Rec TC Out"), _T("Durata Montato"),
                _T("Costo Segmento ") + cur, _T("Note"), _T("Audio Eccedente")]
    for c, h in enumerate(vis_hdrs, 1):
        _a(ws.cell(1, c), h, fill=_fill(C_HEADER),
           font=_font(bold=True, color=C_WHITE),
           align=Alignment(horizontal="center", wrap_text=True))

    help_hdrs = ["_SrcIn_fr", "_SrcOut_fr", "_DurSrc_fr", "_RecIn_fr", "_RecOut_fr", "_DurMon_fr",
                 "_FrUnici", "_Fatturabile"]
    for c, h in enumerate(help_hdrs, 14):
        _a(ws.cell(1, c), h, fill=_fill(C_HELP), font=_font(size=8, color="666666"))

    for col in ["N","O","P","Q","R","S","T","U"]:
        ws.column_dimensions[col].hidden = True
        ws.column_dimensions[col].width  = 10

    ws.auto_filter.ref = "A1:M1"
    ws.freeze_panes   = "A2"

    r = 2

    if sort_bank:
        bank_groups = defaultdict(list)
        for row in rows:
            bank_groups[row.get("dbName", "")].append(row)

        for bank_name in sorted(bank_groups.keys()):
            bank_rows = bank_groups[bank_name]

            # Separatore banca (top)
            ws.cell(r, 1).value = f"── {bank_name} ──"
            ws.cell(r, 1).font  = _font(bold=True, size=10, color=C_WHITE)
            for c in range(1, 14):
                ws.cell(r, c).fill = _fill(C_HEADER)
            r += 1

            row_idx = 0
            for row in bank_rows:
                for seg_idx, seg in enumerate(row.get("segments", [])):
                    fill = _fill(C_ALT) if row_idx % 2 == 1 else _fill(C_WHITE)
                    _write_seg_row(ws, r, row, seg, fill, MF, seg_idx)
                    row_idx += 1
                    r += 1

            # Subtotale banca (bottom)
            _write_sub_row(ws, r, _T("Subtotale: ") + bank_name, bank_name)
            r += 1

    else:
        # Ordine montaggio — header file IN CIMA per clip multi-segmento
        row_idx = 0
        for row in rows:
            segs      = row.get("segments", [])
            db_name   = row.get("dbName", "")
            has_multi = len(segs) > 1

            if has_multi:
                _write_sub_row(ws, r, _T("Subtotale: ") + row.get("mediaName", ""), db_name)
                r += 1

            for seg_idx, seg in enumerate(segs):
                fill = _fill(C_ALT) if row_idx % 2 == 1 else _fill(C_WHITE)
                _write_seg_row(ws, r, row, seg, fill, MF, seg_idx)
                row_idx += 1
                r += 1

    widths = {"A":36,"B":10,"C":28,"D":22,"E":11,"F":11,"G":14,
              "H":11,"I":11,"J":14,"K":14,"L":52,"M":14}
    for col, w in widths.items():
        ws.column_dimensions[col].width = w


# ─────────────────────────────────────────────────────────────────────────────
# SHEET 1 — Riepilogo
# ─────────────────────────────────────────────────────────────────────────────

# Utilizzo Minimo: col F di Config (indice VLOOKUP 6).
# Per modelli temporali: secondi_effettivi = MAX(frames/FPS, utilMin).
# Per "A clip" e "Forfait": ignorato.
_B_FORMULA = (
    '=IFERROR('
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0)=0,"{tbd}",'
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_second}",'
    'CEILING(MAX(G{r}/{sh_cfg}!$B$1,IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,6,0),0)),1)'
    '*VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0),'
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_minute}",'
    'CEILING(MAX(G{r}/{sh_cfg}!$B$1,IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,6,0),0))/60,1)'
    '*VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0),'
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_block}",'
    'CEILING(MAX(G{r}/{sh_cfg}!$B$1,IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,6,0),0))'
    '/IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,5,0),30),1)'
    '*VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0),'
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_clip}",'
    'COUNTIFS({sh_seg}!$C$2:$C$5000,A{r},{sh_seg}!$U$2:$U$5000,1)'
    '*VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0),'
    'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,3,0)="{m_flat}",'
    'VLOOKUP(A{r},{sh_cfg}!$A$3:$G$202,4,0),'
    '"?")))))),  '
    '"{tbd}")'
)

_F_FORMULA = (
    '=IFERROR(TEXT(INT(G{r}/{sh_cfg}!$B$1/3600),"00")&":"'
    '&TEXT(INT(MOD(G{r}/{sh_cfg}!$B$1,3600)/60),"00")&":"'
    '&TEXT(INT(MOD(G{r}/{sh_cfg}!$B$1,60)),"00")&":"'
    '&TEXT(MOD(G{r},{sh_cfg}!$B$1),"00"),"")'
)

# Durata della banca: somma i fotogrammi NON già conteggiati (colonna T), non
# quelli totali del segmento (colonna P). Sommando P, un'inquadratura riusata
# tre volte veniva misurata tre volte, e il foglio fatturava più del motore.
_G_VIDEO = '=SUMPRODUCT(({sh_seg}!$C$2:$C$5000=A{r})*({sh_seg}!$B$2:$B$5000="{t_video}")*{sh_seg}!$T$2:$T$5000)'
_G_NONTV = '=SUMPRODUCT(({sh_seg}!$C$2:$C$5000=A{r})*{sh_seg}!$T$2:$T$5000)'

# Conteggio clip per il modello "A clip": conta solo i segmenti da pagare
# (colonna U = 1). Esclude per costruzione sia le comparse successive della
# stessa clip sorgente sia le righe di struttura, che in U non scrivono nulla.
_CONTA_CLIP = 'COUNTIFS({sh_seg}!$C$2:$C$5000,A{r},{sh_seg}!$U$2:$U$5000,1)'
_CONTA_DUPL = '=COUNTIFS({sh_seg}!$C$2:$C$5000,A{r},{sh_seg}!$U$2:$U$5000,0)'

# Formula sconto automatico da soglie Config.
#
# Config colonne visibili (input utente):
#   H,J,L,N,P = soglie 1-5 (minuti per modelli temporali, clip per "A clip")
#   I,K,M,O,Q = sconti 1-5 (%)
#
# Config colonne nascoste R-V (indici VLOOKUP 18-22):
#   =IF(C{r}="A clip", soglia, soglia*60) — converte min→sec; clip restano invariate.
#
# "uso" = secondi effettivi (frames÷FPS) per modelli temporali, clip count per "A clip".
# Sconto = flat sul costo lordo B. Soglia = 0 → tier disabilitato.
def _D_formula(r):
    sh_cfg = LBL["sh_cfg"]          # nome del foglio Config, tradotto
    uso = (
        f'IF(VLOOKUP(A{r},{sh_cfg}!$A$3:$V$202,3,0)="{LBL["m_clip"]}",'
        f'C{r},INT(G{r}/{sh_cfg}!$B$1))'
    )
    # soglie convertite: R=18, S=19, T=20, U=21, V=22
    # sconti:           I=9,  K=11, M=13, O=15, Q=17
    conv_cols = [18, 19, 20, 21, 22]
    disc_cols = [ 9, 11, 13, 15, 17]

    expr = '""'
    for n in range(1, 6):
        col_s = conv_cols[n - 1]
        col_d = disc_cols[n - 1]
        s = f'IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$V$202,{col_s},0),0)'
        d = f'IFERROR(VLOOKUP(A{r},{sh_cfg}!$A$3:$V$202,{col_d},0),0)'
        expr = f'IF(({uso}>={s})*({s}>0),{d},{expr})'
    return f'=IFERROR({expr},"")'

def _E_formula(r):
    tbd = LBL["tbd"]
    return (
        f'=IFERROR(IF(B{r}="{tbd}","{tbd}",'
        f'IF(D{r}="",B{r},B{r}*(1-D{r}/100))),"{tbd}")'
    )


def _write_section(ws, cat, bank_names, r_start, db_entries, db_uncovered, db_total_sec, cur, MF):
    tbd = LBL["tbd"]
    r = r_start
    cat_label = etichetta_media(cat).upper()

    # Header categoria
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=10)
    _a(ws.cell(r, 1), cat_label,
       fill=_fill(C_HEADER), font=_font(bold=True, size=11, color=C_WHITE))
    for c in range(2, 11):
        ws.cell(r, c).fill = _fill(C_HEADER)
    r += 1

    # Header colonne — dieci, quante sono le colonne scritte sotto.
    # La settima resta senza titolo: contiene la somma dei frame, che serve
    # alle formule delle altre colonne e non si legge come dato.
    hdrs = [_T("Banca Dati"), _T("Costo Lordo ") + cur, _T("Occorrenze"),
            _T("Sconto %"), _T("Costo Netto ") + cur, _T("Durata totale"), "",
            _T("Secondi Scoperti"), _T("Riusate"), _T("Note")]
    for c, h in enumerate(hdrs, 1):
        _a(ws.cell(r, c), h,
           fill=_fill(C_HEADER), font=_font(bold=True, size=9, color=C_WHITE),
           align=Alignment(horizontal="center"))
    r += 1

    bank_rows = []
    for i, name in enumerate(bank_names):
        row_fill = _fill(C_ALT) if i % 2 == 1 else _fill(C_WHITE)
        bank_rows.append(r)

        _a(ws.cell(r, 1), name, fill=row_fill, vborder=True)
        _a(ws.cell(r, 2), _B_FORMULA.format(r=r, **LBL).strip(),
           fill=row_fill, vborder=True, num_fmt=MF)
        _a(ws.cell(r, 3), '=' + _CONTA_CLIP.format(r=r, **LBL),
           fill=row_fill, vborder=True, num_fmt='0')
        _a(ws.cell(r, 4), _D_formula(r), fill=row_fill, vborder=True,
           num_fmt='0.00')
        _a(ws.cell(r, 5), _E_formula(r),
           fill=row_fill, vborder=True, num_fmt=MF)
        _a(ws.cell(r, 6), _F_FORMULA.format(r=r, **LBL), fill=row_fill, vborder=True)
        g = (_G_VIDEO.format(r=r, **LBL) if cat == "Video"
             else _G_NONTV.format(r=r, **LBL))
        _a(ws.cell(r, 7), g, fill=row_fill, vborder=True)
        # Colonna "Secondi Scoperti" — mostra deficit se utilizzo < minimo.
        # I secondi usati e quelli scoperti devono sommare al minimo: chi legge
        # fa la sottrazione. Arrotondandoli separatamente non tornava
        # (16,28 e 13,72 diventavano 16 e 13, somma 29 su un minimo di 30),
        # quindi si arrotonda il primo e il secondo si ricava per differenza.
        uncovered_text = ""
        entry = db_entries.get(name)
        if entry and entry.get("utilMin") and entry.get("utilMin") > 0:
            uncov = db_uncovered.get(name)
            total = db_total_sec.get(name, 0)
            if uncov and uncov > 0:
                util  = int(entry["utilMin"])
                usati = int(round(total))
                usati = max(0, min(usati, util))
                uncovered_text = (_T("Min %ds - Usati %ds - Scoperti %ds")
                                  % (util, usati, util - usati))
        _a(ws.cell(r, 8), uncovered_text, fill=row_fill, vborder=True,
           font=_font(size=9, color="B03020"))
        # "Riusate": quante comparse non si pagano perché già conteggiate
        _a(ws.cell(r, 9), _CONTA_DUPL.format(r=r, **LBL), fill=row_fill, vborder=True,
           num_fmt='0;;"-"')
        _a(ws.cell(r, 10), fill=row_fill, vborder=True)
        r += 1

    # Subtotale
    r_sub = r
    sub_e = "+".join(f'IF(E{br}="{tbd}",0,E{br})' for br in bank_rows) if bank_rows else "0"
    sub_g = "+".join(f'G{br}' for br in bank_rows) if bank_rows else "0"

    sub_i = "+".join(f'I{br}' for br in bank_rows) if bank_rows else "0"

    for c in range(1, 11):
        ws.cell(r_sub, c).fill = _fill(C_SUB_RP)
    _a(ws.cell(r_sub, 1), _T("SUBTOTALE ") + cat_label,
       fill=_fill(C_SUB_RP), font=_font(bold=True))
    _a(ws.cell(r_sub, 9), f"={sub_i}",
       fill=_fill(C_SUB_RP), font=_font(bold=True), num_fmt='0;;"-"')
    _a(ws.cell(r_sub, 5), f"={sub_e}",
       fill=_fill(C_SUB_RP), font=_font(bold=True), num_fmt=MF)
    _a(ws.cell(r_sub, 6), _F_FORMULA.format(r=r_sub, **LBL),
       fill=_fill(C_SUB_RP), font=_font(bold=True))
    _a(ws.cell(r_sub, 7), f"={sub_g}", fill=_fill(C_SUB_RP), font=_font(bold=True))

    return r_sub + 2, r_sub


def write_riepilogo(ws, data):
    tbd = LBL["tbd"]
    cur = data.get("currencySymbol", "\u20ac")
    MF  = money_fmt(cur)
    db_entries      = as_dict(data.get("dbEntryByName", {}))
    by_db           = as_dict(data.get("byDB", {}))
    db_uncovered    = as_dict(data.get("dbUncoveredSec", {}))
    db_total_sec    = as_dict(data.get("dbTotalSec", {}))
    tl_name         = data.get("timelineName", "")
    fps             = data.get("fps", 25)
    generated       = data.get("generated", "")
    version         = data.get("version", "")

    cats   = ["Video", "Fotografie", "Giornali"]          # valori canonici
    by_cat = {c: [] for c in cats}
    for name in sorted(by_db.keys()):
        mt = db_entries.get(name, {}).get("mediaType", "Video")
        by_cat.get(mt, by_cat["Video"]).append(name)

    # Intestazione semplice
    ws.merge_cells("A1:J1")
    _a(ws.cell(1, 1), "RepertoireDB %s — %s" % (version, _T("Riepilogo costi repertorio")),
       font=_font(bold=True, size=14))
    ws.merge_cells("A2:J2")
    _a(ws.cell(2, 1), _T("Timeline: ") + tl_name, font=_font(size=11))
    ws.merge_cells("A3:J3")
    _a(ws.cell(3, 1), _T("Generato: ") + generated, font=_font(size=9, color="888888"))

    r = 5
    subtot_rows = {}
    for cat in cats:
        names = by_cat.get(cat, [])
        if not names:
            continue
        r, r_sub = _write_section(ws, cat, names, r, db_entries, db_uncovered, db_total_sec, cur, MF)
        subtot_rows[cat] = r_sub

    r_tot  = r
    subs_e = "+".join(
        f'IF(E{subtot_rows[c]}="{tbd}",0,E{subtot_rows[c]})'
        for c in cats if c in subtot_rows
    ) or "0"
    subs_g = "+".join(f'G{subtot_rows[c]}' for c in cats if c in subtot_rows) or "0"
    subs_i = "+".join(f'I{subtot_rows[c]}' for c in cats if c in subtot_rows) or "0"

    for c in range(1, 11):
        ws.cell(r_tot, c).fill = _fill(C_TOT)
    _a(ws.cell(r_tot, 1), _T("TOTALE GENERALE"),
       fill=_fill(C_TOT), font=_font(bold=True, size=12, color=C_WHITE))
    _a(ws.cell(r_tot, 5), f"={subs_e}",
       fill=_fill(C_TOT), font=_font(bold=True, size=12, color=C_WHITE),
       num_fmt=MF)
    _a(ws.cell(r_tot, 6), _F_FORMULA.format(r=r_tot, **LBL),
       fill=_fill(C_TOT), font=_font(bold=True, color=C_WHITE))
    _a(ws.cell(r_tot, 7), f"={subs_g}",
       fill=_fill(C_TOT), font=_font(bold=True, color=C_WHITE))
    _a(ws.cell(r_tot, 9), f"={subs_i}",
       fill=_fill(C_TOT), font=_font(bold=True, color=C_WHITE), num_fmt='0;;"-"')

    r_leg = r_tot + 2
    ws.merge_cells(start_row=r_leg, start_column=1, end_row=r_leg, end_column=10)
    ws.cell(r_leg, 1).value = _T("Legenda:  ") + "  |  ".join([
        _T("D=Sconto % auto (soglie in Config H-Q: minuti per modelli temporali, clip per 'A clip') — sovrascrivibile manualmente"),
        _T("F=Utilizzo Min.(sec): se > 0 il costo usa MAX(durata_reale, F)"),
        _T("C=Occorrenze: solo le clip che si pagano"),
        _T("I=Riusate: comparse non fatturate perché il materiale era già conteggiato (una ripetuta in parte resta fatturata per la sua parte nuova e non compare qui)"),
        _T("🟠 nel foglio Segmenti = materiale già conteggiato"),
    ])
    ws.cell(r_leg, 1).font = _font(size=8, color="888888")

    for col, w in [("A",34),("B",14),("C",12),("D",10),("E",14),("F",14),("G",16),("H",28),
                   ("I",10),("J",36)]:
        ws.column_dimensions[col].width = w


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print("ERR:Usage: RepertoireDB_xlsx.py <json_path> <output_xlsx>")
        sys.exit(1)

    json_path   = sys.argv[1]
    output_path = sys.argv[2]

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERR:Lettura JSON: {e}")
        sys.exit(1)

    # Prima di scrivere qualunque cosa: il testo delle celle e i letterali
    # dentro le formule che lo confrontano escono dalla stessa tabella.
    carica_etichette(data)

    try:
        wb = Workbook()

        ws_riep = wb.active
        ws_riep.title = _T("Riepilogo")
        write_riepilogo(ws_riep, data)

        ws_seg = wb.create_sheet(_T("Segmenti"))
        write_segmenti(ws_seg, data)

        ws_cfg = wb.create_sheet(_T("Config"))
        write_config(ws_cfg, data)

        wb.save(output_path)
        print(f"OK:{output_path}")
    except Exception as e:
        import traceback
        print(f"ERR:{e}\n{traceback.format_exc()}")
        sys.exit(1)


if __name__ == "__main__":
    main()
