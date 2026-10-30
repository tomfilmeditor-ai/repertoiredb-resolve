#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controlli meccanici sulle traduzioni, prima che finiscano nel codice.

Non giudica la qualità della lingua: verifica le cose che un errore umano
sbaglia in silenzio e che a schermo diventano un crash o un numero nel posto
sbagliato.

Uso:  python3 verifica_traduzioni.py          # esce 1 se trova problemi
"""
import json
import re
import subprocess
import sys
from pathlib import Path

QUI = Path(__file__).parent
sys.path.insert(0, str(QUI))
from traduzioni_en import EN  # noqa: E402

RE_PH = re.compile(r'%%|%[-+ #0-9.]*[sdifgqxX]')


def main():
    dati = json.loads(subprocess.check_output(
        [sys.executable, "-I", str(QUI / "estrai_T.py")], text=True))
    stringhe = {s["string"]: s for s in dati["stringhe"]}

    problemi = []

    # 1. ogni stringa del codice deve avere una traduzione
    mancanti = [s for s in stringhe if s not in EN]
    for s in mancanti:
        problemi.append(("MANCA LA TRADUZIONE", s, ""))

    # 2. nessuna traduzione di troppo (segno che il codice è cambiato)
    orfane = [s for s in EN if s not in stringhe]
    for s in orfane:
        problemi.append(("TRADUZIONE ORFANA — non è più nel codice", s, ""))

    for it, en in EN.items():
        if it not in stringhe:
            continue
        info = stringhe[it]

        # 3. traduzione vuota
        if not en.strip():
            problemi.append(("TRADUZIONE VUOTA", it, en))
            continue

        # 4. segnaposto: stessi, nello stesso numero. L'ORDINE conta, perché
        #    string.format li riempie in sequenza: scambiarli mette i valori
        #    nei posti sbagliati senza dare errore.
        if info["formattata"]:
            a, b = RE_PH.findall(it), RE_PH.findall(en)
            if a != b:
                problemi.append(("SEGNAPOSTO DIVERSI: %s -> %s" % (a, b), it, en))

        # 5. un % letterale in una stringa formattata è un crash in attesa
        if info["formattata"]:
            senza = RE_PH.sub("", en)
            if "%" in senza:
                problemi.append(("PERCENTO NON VALIDO (usa %%)", it, en))

        # 6. ritorni a capo: stesso numero
        if it.count("\\n") != en.count("\\n"):
            problemi.append(("RITORNI A CAPO DIVERSI", it, en))

        # 7. spazi iniziali e finali: servono ad allineare le colonne
        def bordi(s):
            return (len(s) - len(s.lstrip(" ")), len(s) - len(s.rstrip(" ")))
        if bordi(it) != bordi(en):
            problemi.append(("SPAZI AI BORDI DIVERSI: %s -> %s"
                             % (bordi(it), bordi(en)), it, en))

        # 8. simboli e icone: devono restare tutti
        SIMBOLI = "✓⚠✕▶↩↺↳▸→·⏭💾📂🗑"
        for ch in SIMBOLI:
            if it.count(ch) != en.count(ch):
                problemi.append(("SIMBOLO %s PERSO O AGGIUNTO" % ch, it, en))

        # 9. virgolette escapate: stesso numero, o il Lua non compila
        if it.count('\\"') != en.count('\\"'):
            problemi.append(("VIRGOLETTE ESCAPATE DIVERSE", it, en))

    print("stringhe nel codice : %d" % len(stringhe))
    print("traduzioni presenti : %d" % len(EN))
    print("con segnaposto      : %d" % sum(
        1 for s in stringhe.values() if s["formattata"]))
    print()
    if not problemi:
        print("nessun problema meccanico")
        return 0
    print("PROBLEMI: %d\n" % len(problemi))
    for tipo, it, en in problemi:
        print("  %s" % tipo)
        print("     IT: %s" % repr(it))
        if en:
            print("     EN: %s" % repr(en))
    return 1


if __name__ == "__main__":
    sys.exit(main())
