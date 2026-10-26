# RepertoireDB

**Archive footage cost calculator for DaVinci Resolve.**
Reads your timeline and works out what the archive material in it will cost.

🇮🇹 [Leggi in italiano](README.it.md)

![Version](https://img.shields.io/badge/version-1.2.13-blue)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey)
![Resolve](https://img.shields.io/badge/DaVinci%20Resolve-Studio%2019%2F20-orange)
![License](https://img.shields.io/badge/license-MIT-green)

<!-- SCREENSHOT: replace this comment with an image of the Calculator window.
     Suggested: docs/images/calculator.png — it is the single thing that makes
     people download a tool like this. -->

---

## The problem this solves

On an archive-heavy documentary, working out licensing costs is slow and
error-prone. Every archive has its own pricing model — per second, per minute,
per clip, in blocks, or a flat fee — each with its own discount rules and
minimum billable duration. And the cut keeps changing until the last day.

Doing this by hand means a spreadsheet that is out of date the moment you trim
a shot.

RepertoireDB reads the timeline directly: you tag each clip with the archive it
came from, and it produces the cost breakdown. When the cut changes, you run it
again.

Written by a working film editor, for his own documentaries.

---

## What it does

Three scripts that work together:

| Script | What it is for |
|---|---|
| **Config** | Your archive database: pricing models, rates, discounts, minimum usage |
| **Calculator** | Reads a timeline and produces the cost report |
| **Monitor** | A floating window that keeps a running total while you edit |

**Pricing models**: per clip · per second · per minute · custom blocks · flat fee
(video supports all of them; photo and newspaper archives use per clip or flat fee)

**It also handles:**

- **Discounts** — tiered (only on the excess) or flat (on everything), with the
  threshold set in seconds or in number of clips
- **Duplicate detection** — if the same source frames appear twice in the cut,
  they are billed once
- **Retiming** — detects slow motion, time warp, freeze frames and reverse
- **Minimum billable duration** — when actual usage falls below an archive's
  minimum, the report shows the gap
- **Audio beyond video coverage** — audio-only usage billed at 50%
- **Export** — a full report to CSV or Excel (`.xlsx`)

> **The figures are indicative.** The report is a working estimate, not the
> production's official costing. Contractual terms vary and always take
> precedence.

---

## Installation

Download the installer for your system from the
[Releases page](../../releases), then:

**macOS** — **right-click** the `.command` file and choose **Open**
(not a double-click: the installer is not signed with an Apple certificate, and
a double-click gets blocked).

**Windows** — double-click the `.cmd` file. If SmartScreen warns you, choose
*More info* → *Run anyway*.

The installer puts the files in the two places Resolve needs them and tells you
when it is done. Then, in Resolve:

    Workspace > Scripts > Comp > RepertoireDB_Config

Installing manually? The scripts in `scripts/` go in
`Fusion/Scripts/Comp/RepertoireDB/`, and the two modules in `modules/` go in
`Fusion/Modules/Lua/` — **two different folders**. The scripts will not start if
the modules are in the wrong place.

---

## Requirements

- **DaVinci Resolve Studio 19 or 20.** The free version will not work: since
  Resolve 19.1 the scripting interface these tools are built on (UIManager) is
  Studio-only.
- macOS or Windows
- For Excel export only: Python 3 with `openpyxl` (there is a helper script,
  `RepertoireDB_Installer.lua`, that sets this up)

---

## Known limits

- **Studio only** — see above
- **Retimed clips**: timecode on heavily retimed or variable-speed clips can be
  approximate; the calculation assumes 100% speed where Resolve does not report
  otherwise
- **Unusual frame rates**: non-standard or variable frame rates give approximate
  results
- **Windows**: the code is cross-platform and the installer is built for both,
  but day-to-day use is tested on macOS
- The tool reads what is in the timeline. It cannot know about contractual
  terms you have not entered into the archive database

---

## Documentation

- [User manual](docs/) — the full guide
- [CHANGELOG](CHANGELOG.md) — what changed in each version

---

## Reporting a problem

Open an [Issue](../../issues) — it is the best way, because other people with
the same problem will find the answer.

The scripts also have a 🐛 button that opens a pre-filled email with your system
details, and keep a log file you can attach:

- macOS: `~/Library/Logs/RepertoireDB/repertoire_db.log`
- Windows: `%LOCALAPPDATA%\Blackmagic Design\DaVinci Resolve\Logs\RepertoireDB\`

A note on what you are dealing with: these scripts are written by an editor, not
a professional developer. The code works and is used on real productions, but do
not expect the conventions of a software project.

---

## Credits

**Tommaso Feraboli** — Film Editor
Licensed under [MIT](LICENSE.md) · Copyright (c) 2024-2026

If it saves you time: [buy me a coffee](https://paypal.me/acoffeefortom) ☕
