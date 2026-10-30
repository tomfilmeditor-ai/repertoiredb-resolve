#!/usr/bin/env python3
"""Estrae le stringhe traducibili dai tre script Lua di RepertoireDB.

Sostituisce `estrai_stringhe.py`, che cercava di indovinare quali letterali
fossero testo d'interfaccia guardando il nome della proprietà Fusion. Da
quando ogni testo mostrato all'utente passa per T("..."), non c'è più niente
da indovinare: le stringhe traducibili sono esattamente gli argomenti di T.

Uso:  python3 estrai_T.py > stringhe.json
"""
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

SRC = Path("/Users/tommaso/Library/Application Support/Blackmagic Design/"
           "DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB")

FILES = OrderedDict([
    ("config",     "RepertoireDB_Config.lua"),
    ("calculator", "RepertoireDB_Calculator.lua"),
    ("monitor",    "RepertoireDB_Monitor.lua"),
])

# T("...") — un solo argomento, un letterale fra virgolette doppie.
RE_T = re.compile(r'\bT\(\s*"((?:[^"\\]|\\.)*)"\s*\)')

# Segnaposto di string.format: devono restare identici nella traduzione.
RE_PH = re.compile(r'%%|%[-+ #0-9.]*[sdifgqxX]')

# Una stringa ha segnaposto veri solo se finisce dentro string.format. Senza
# questo controllo, "fatturati al 50% della tariffa" risulterebbe contenere un
# segnaposto "% d" (il flag spazio di printf) e il traduttore riceverebbe
# l'istruzione di preservare qualcosa che non esiste.
def dentro_format(text, pos):
    """True se la chiamata T( che inizia a pos è il primo argomento di
    string.format, anche attraverso un operatore ternario Lua
    (`cond and T("uno") or T("altro")`)."""
    prima = text[max(0, pos - 220):pos]
    i = prima.rfind("string.format(")
    if i < 0:
        return False
    fra = prima[i + len("string.format("):]
    # Le altre chiamate T("...") che stanno in mezzo vanno tolte prima del
    # controllo: nei plurali il secondo ramo del ternario è preceduto dal
    # primo, `string.format(n == 1 and T("uno") or T("altri"), n)`, e la
    # parentesi chiusa di quel primo farebbe concludere di essere fuori.
    fra = RE_T.sub("", fra)
    # Restano spazi, o una condizione ternaria. Una virgola o una parentesi
    # chiusa a questo punto vogliono dire che siamo in un argomento
    # successivo, non nel modello di formato.
    return "," not in fra and ")" not in fra


def main():
    per_file = OrderedDict()
    dedup = OrderedDict()

    for key, fname in FILES.items():
        path = SRC / fname
        if not path.exists():
            print(f"MANCA: {path}", file=sys.stderr)
            continue
        text = path.read_text(encoding="utf-8")
        n = 0
        for m in RE_T.finditer(text):
            raw = m.group(1)
            line = text[:m.start()].count("\n") + 1
            n += 1
            fmt = dentro_format(text, m.start())
            if raw not in dedup:
                dedup[raw] = {
                    "string": raw,
                    "formattata": fmt,
                    "placeholders": RE_PH.findall(raw) if fmt else [],
                    "multiline": "\\n" in raw,
                    "where": [],
                }
            dedup[raw]["where"].append(f"{fname}:{line}")
            if fmt and not dedup[raw]["formattata"]:
                dedup[raw]["formattata"] = True
                dedup[raw]["placeholders"] = RE_PH.findall(raw)
        per_file[key] = n

    print(json.dumps({
        "occorrenze_per_file": per_file,
        "occorrenze_totali": sum(per_file.values()),
        "stringhe_uniche": len(dedup),
        "con_segnaposto": sum(1 for v in dedup.values() if v["placeholders"]),
        "su_piu_righe": sum(1 for v in dedup.values() if v["multiline"]),
        "stringhe": list(dedup.values()),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
