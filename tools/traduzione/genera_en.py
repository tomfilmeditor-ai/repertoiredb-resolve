#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Produce due cose dalla stessa fonte (traduzioni_en.py):

  1. RepertoireDB_TRADUZIONE_EN.md  — da rileggere prima di pubblicare
  2. Strings.lua                    — il modulo che va in Fusion/Modules/Lua/

Un solo posto da correggere: se rileggendo il markdown trovi una frase da
cambiare, la si cambia in traduzioni_en.py e si rigenera. Il markdown non è
la fonte, è una vista.
"""
import json
import subprocess
import sys
from pathlib import Path

QUI = Path(__file__).parent
sys.path.insert(0, str(QUI))
from traduzioni_en import EN  # noqa: E402

PROGETTO = QUI.parent
MD_OUT = PROGETTO / "RepertoireDB_TRADUZIONE_EN.md"
LUA_OUT = PROGETTO / "ARCHIVE" / "Strings.lua"

GRUPPI = [
    ("RepertoireDB_Config.lua", "Config — configurazione delle banche dati"),
    ("RepertoireDB_Calculator.lua", "Calculator — calcolo dei costi"),
    ("RepertoireDB_Monitor.lua", "Monitor — finestra di controllo"),
]


def lua_quote(s):
    """Il testo arriva già con le escape del Lua (\\" e \\n) perché è stato
    letto dal codice: va riscritto identico, raddoppiando solo le barre che
    non fanno parte di una escape già valida."""
    return '"' + s + '"'


def main():
    dati = json.loads(subprocess.check_output(
        [sys.executable, "-I", str(QUI / "estrai_T.py")], text=True))
    info = {s["string"]: s for s in dati["stringhe"]}

    # ── markdown per la rilettura ────────────────────────────────────────
    md = []
    md.append("# RepertoireDB — Traduzione inglese dell'interfaccia\n")
    md.append("Riferita alla **v1.4.0**. Generata da `tools-traduzione/genera_en.py`: "
              "per correggere una frase si modifica `traduzioni_en.py` e si rigenera, "
              "non si scrive qui dentro.\n")
    md.append("**%d stringhe** su %d occorrenze nel codice.\n"
              % (dati["stringhe_uniche"], dati["occorrenze_totali"]))
    md.append("## Come rileggere\n")
    md.append("Le righe segnate **F** passano da `string.format`: i segnaposto "
              "(`%s`, `%d`, `%.3f`, `%%`) devono restare identici e **nello stesso "
              "ordine**, perché il programma li riempie in sequenza. Già verificato "
              "meccanicamente da `verifica_traduzioni.py`, che controlla anche "
              "simboli, ritorni a capo e spazi ai bordi.\n")
    md.append("Quello che serve dalla tua rilettura è la **lingua**: se un pulsante "
              "suona giusto a un montatore inglese, se un messaggio di errore si "
              "capisce, se un termine è quello che usereste in sala.\n")
    md.append("## Glossario usato\n")
    md.append("| Italiano | Inglese |\n|---|---|")
    for a, b in [("banca dati", "archive"), ("banche (conteggio)", "archives"),
                 ("repertorio", "archive footage"), ("tariffa", "rate"),
                 ("modello pricing", "pricing model"),
                 ("utilizzo minimo", "minimum usage"), ("sconto", "discount"),
                 ("soglia", "threshold"), ("audio eccedente", "excess audio"),
                 ("inutilizzati", "unused"), ("dettaglio", "breakdown"),
                 ("riepilogo", "summary"), ("arrotondato a", "rounded up to"),
                 ("proporzionale", "pro rata"), ("fatturato", "billed"),
                 ("ripetuto", "repeated"), ("segmento", "segment")]:
        md.append("| %s | %s |" % (a, b))
    md.append("")

    visti = set()
    for fname, titolo in GRUPPI:
        righe = [s for s in dati["stringhe"]
                 if any(w.startswith(fname) for w in s["where"])
                 and s["string"] not in visti]
        if not righe:
            continue
        md.append("\n---\n\n## %s\n" % titolo)
        md.append("| | Italiano | Inglese |")
        md.append("|---|---|---|")
        for s in righe:
            visti.add(s["string"])
            it = s["string"]
            en = EN.get(it, "")
            f = "**F**" if s["formattata"] else ""
            def cella(x):
                return (x.replace("|", "\\|").replace("\\n", "⏎")
                         .replace("\\\"", '"') or "*(vuoto)*")
            md.append("| %s | %s | %s |" % (f, cella(it), cella(en)))
        md.append("")

    MD_OUT.write_text("\n".join(md), encoding="utf-8")

    # ── modulo Lua ───────────────────────────────────────────────────────
    lua = []
    lua.append("-- ==============================================================")
    lua.append("-- Strings.lua — traduzioni dell'interfaccia RepertoireDB")
    lua.append("--")
    lua.append("-- FILE GENERATO. Non modificare a mano: si rigenera con")
    lua.append("--   tools-traduzione/genera_en.py")
    lua.append("-- a partire da tools-traduzione/traduzioni_en.py, che è la fonte.")
    lua.append("--")
    lua.append("-- La chiave è il testo italiano esattamente come compare nel codice")
    lua.append("-- dentro T(\"...\"). Se una chiave non si trova, o questo file non è")
    lua.append("-- installato, l'interfaccia resta in italiano senza dare errore.")
    lua.append("--")
    lua.append("-- Va in Fusion/Modules/Lua/ insieme agli altri moduli condivisi.")
    lua.append("--")
    lua.append("-- Autore: Tommaso Feraboli — Film Editor")
    lua.append("-- Licenza MIT")
    lua.append("-- ==============================================================")
    lua.append("")
    lua.append("return {")
    lua.append("    en = {")
    for fname, titolo in GRUPPI:
        lua.append("        -- %s" % titolo)
        for s in dati["stringhe"]:
            if not any(w.startswith(fname) for w in s["where"]):
                continue
            it = s["string"]
            en = EN.get(it)
            if en is None:
                continue
            lua.append("        [%s] = %s," % (lua_quote(it), lua_quote(en)))
        lua.append("")
    lua.append("    },")
    lua.append("}")
    LUA_OUT.parent.mkdir(parents=True, exist_ok=True)
    LUA_OUT.write_text("\n".join(lua) + "\n", encoding="utf-8")

    print("scritti:")
    print("  %s" % MD_OUT)
    print("  %s" % LUA_OUT)


if __name__ == "__main__":
    main()
