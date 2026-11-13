================================================================
RepertoireDB  v1.4.1
Archive footage cost calculator for DaVinci Resolve

Tommaso Feraboli — Film Editor
MIT Licence · Copyright (c) 2024-2026
Bug reports: tomfilmeditor.tools@gmail.com
Source: https://github.com/tomfilmeditor-ai/repertoiredb-resolve
================================================================

A note on this manual: the Italian manual (RepertoireDB_README.txt)
is longer and goes into more detail on a few topics. This English
manual covers everything you need to use the tool. Where the Italian
one has more, it is noted in the text.


WHAT IT IS
----------
Three scripts for DaVinci Resolve that work out what the archive
footage in your timeline will cost to licence.

  Config      Your archive database: pricing models, rates,
              discounts, minimum billable usage
  Calculator  Reads a timeline and produces the full cost report
  Monitor     A small floating window showing how much you have
              used from each archive, while you edit

You tag clips with the archive they came from; the tool reads the
timeline and does the arithmetic. When the cut changes, run it again.


REQUIREMENTS
------------
  * DaVinci Resolve STUDIO 19 or 20.
    The free version will NOT work. Since Resolve 19.1 the scripting
    interface these tools are built on (UIManager) is Studio-only.
    This is Blackmagic's decision and there is no way around it.

  * macOS or Windows. Linux works but is installed by hand.

  * For Excel export only: Python 3 with openpyxl.
    There is a helper script, RepertoireDB_Installer.lua, that sets
    this up. CSV export needs nothing extra.


INSTALLATION
------------
Download the installer for your system from the Releases page.

macOS — two steps, because macOS puts two different obstacles in
the way:

  1. Double-click the .zip to unpack it. Downloading a file over the
     web strips its Unix permissions, so the installer arrives unable
     to run. Inside the zip the permission survives.

  2. Right-click the unpacked .command file and choose Open — not a
     double-click. The installer is not signed with an Apple
     certificate, and only this way do you get the dialog with the
     Open button.

Windows — double-click the .cmd file. If SmartScreen warns you,
choose "More info" then "Run anyway".

Then, in Resolve:

  Workspace > Scripts > Comp > RepertoireDB_Config


INSTALLING BY HAND — TWO DIFFERENT FOLDERS
-------------------------------------------
This is the one thing people get wrong. The files do not all go in
the same place.

1) SCRIPTS — in the Fusion scripts folder:

   macOS  : ~/Library/Application Support/Blackmagic Design/
            DaVinci Resolve/Fusion/Scripts/Comp/RepertoireDB/
   Windows: %APPDATA%\\Blackmagic Design\\DaVinci Resolve\\
            Fusion\\Scripts\\Comp\\RepertoireDB\\

   RepertoireDB_Config.lua
   RepertoireDB_Calculator.lua
   RepertoireDB_Monitor.lua
   RepertoireDB_xlsx.py
   RepertoireDB_Installer.lua

2) SHARED MODULES — in a DIFFERENT folder:

   macOS  : ~/Library/Application Support/Blackmagic Design/
            DaVinci Resolve/Fusion/Modules/Lua/
   Windows: %APPDATA%\\Blackmagic Design\\DaVinci Resolve\\
            Fusion\\Modules\\Lua\\

   LogManager.lua        logging
   BugReportDialog.lua   bug report window
   Settings.lua          currency, language, labels
   Strings.lua           English translation

   The first three are required: without them the scripts will not
   start and you get "module 'LogManager' not found".
   Strings.lua is OPTIONAL: without it the interface stays in
   Italian, with no error.

   Why a different folder: Resolve looks for modules loaded with
   require() only in Modules/Lua, never in the scripts folder.


INTERFACE LANGUAGE
------------------
At the top of the Config window there is a Language menu with three
entries:

  Automatic — <language>   follows your operating system
  Italiano
  English

The Automatic entry names, in brackets, the language the detection
landed on, so you can see what it chose.

IMPORTANT: the detection reads your OPERATING SYSTEM's language, not
DaVinci Resolve's. Those are two different settings — you can have
Resolve in English on an Italian Mac, or the other way round. The one
that matters is the system's, because that is the language you chose
in order to read.

  macOS    the interface language order
           (System Settings > General > Language & Region)
  Windows  the Windows user-interface language
  Linux    the LANG / LC_ALL / LC_MESSAGES variables

If your system language is one the tool does not have a translation
for, the interface stays in Italian. It is never left blank.

Changing the language refreshes the menus and the archive list
straight away. The other windows (Calculator, Monitor) pick up the
new language when you reopen them.

WHAT IS TRANSLATED
  * the interface of all three scripts
  * the CSV cost report
  * the exported Excel workbook, including the three sheet names
    (Summary / Segments / Config)
  * the pricing model and media type names shown in the menus

WHAT IS NOT TRANSLATED, AND WHY
  The values stored in your configuration file stay in Italian:
  "A clip", "Al minuto", "Video", "Fotografie" and so on.

  This is deliberate. Those words are the key the tool uses to find
  each archive's pricing model, and they are also the contents of the
  Model column in the import CSVs, which is a documented, published
  format. Translating them would mean a database built with the
  English interface could no longer be opened with the Italian one.

  On screen you see the translated label; in the file the key stays.

  The Config sheet's own CSV export keeps them too, because it is
  meant to be re-imported — including into someone else's copy, in
  whatever language they use.

  The CSV cost report from the Calculator is a report to be read, so
  it IS translated.


CURRENCY
--------
Next to the Language menu there is a Currency menu: euro, US dollar,
pound sterling, Swiss franc, Canadian and Australian dollar, Chinese
yuan, Japanese yen, Korean won.

It changes the SYMBOL ONLY. Nothing is converted and no exchange rate
is applied. Enter your rates in the currency you actually licence in.

The symbol applies to the interface, the CSV and the Excel workbook.
In the workbook it goes into the cell format rather than the cell
text, so the formulas keep working.

One currency at a time: the setting covers the whole database. If you
licence from archives in different currencies on the same project,
convert the rates yourself before entering them.


SETTING UP AN ARCHIVE  (Config)
--------------------------------
Press "+ New" and fill in the form.

  Archive name       as you want it to appear in the reports
  Media type         Video, Photos or Newspapers. It changes which
                     pricing models are offered: per-second makes no
                     sense for a stills library
  Pricing model      see below
  Rate               the price per unit of the chosen model
  Block length       only for the per-block model
  Minimum usage      see below
  Bill excess audio  when on, audio seconds with no video coverage
                     are billed at 50% of the rate

PRICING MODELS

  Per clip           a fixed price for each source clip, however
                     long and however many times it is used
  Per second         rate × seconds, rounded up
  Per minute         rate × minutes, rounded up
  Per custom block   rate × blocks of N seconds, rounded up
  Flat fee           one price for the whole archive, regardless of
                     how many clips or how long

  Video archives can use all five. Photos and Newspapers use per clip
  or flat fee.

MINIMUM USAGE

  Many archives have a minimum billable duration: you use eight
  seconds, you pay for thirty. Enter it here and the tool bills the
  greater of the two.

  The report says so in plain terms, in the "Shortfall" column:
  "Min 30s - Used 8s - Shortfall 22s".

  0 means no minimum.

DISCOUNTS

  Up to five thresholds per archive. For each one: the threshold, the
  percentage, and the type.

    Flat         the discount applies to the WHOLE amount
    Tiered       the discount applies ONLY to the part above the
                 threshold

  Those are two different contracts and two different numbers. Check
  which one you actually agreed.

  Thresholds are in seconds for time-based models, and in number of
  clips for the per-clip model. The label changes to match.


TAGGING CLIPS
-------------
The tool needs to know which clips came from which archive. It uses
Resolve's flags.

  1. Select the clips in the Media Pool
  2. In Config, press "Tag selected clips"
  3. Choose the archive and press Apply

Each archive gets its own flag colour. "Remove keywords" clears the
tagging from the selected clips.


CALCULATING  (Calculator)
--------------------------
Open RepertoireDB_Calculator, pick the timeline, press CALCULATE.

For each archive you get: gross cost, discount applied, net cost,
total duration, and a Breakdown column that says HOW that number came
about — rounded up to six minutes, flat discount of 15%, thirty-seven
seconds paid for and not used.

REUSED MATERIAL

  If the same source frames appear more than once in the cut, they are
  billed ONCE. Archives licence the material, not the number of times
  you drop it into a timeline.

  The report shows the repeats and marks them "REUSED — not counted",
  so you can see them without paying for them twice.

  A segment that repeats only PART of material already used stays
  billable for its new frames.

RETIMING

  Slow motion, time warp, freeze frames and reverse are detected and
  noted. Timecode on heavily retimed or variable-speed clips can be
  approximate; where Resolve does not report the speed, the
  calculation assumes 100%.


EXPORTING
---------
Press "Export CSV / XLSX". A dialog asks for the format and the order
of the segments section.

CSV — a single text file, opens in anything. It is the report you
read or send.

EXCEL — three sheets linked by live formulas: Config with the
archives, Segments with the clips, Summary with the totals.

  Change a rate or a discount percentage in the Config sheet and
  every clip cost and every total recalculates on its own. No need to
  reopen Resolve or run the script again.

  Useful when the cut is locked but the negotiation is not: try two
  rates in front of the producer and see straight away where the
  estimate lands.

WHAT RECALCULATES IN THE WORKBOOK, AND WHAT DOES NOT

  Recalculates:     rates, discount percentages and thresholds,
                    minimum usage, block length — the commercial
                    terms, the numbers you negotiate over

  Does not:         the billable source durations, and which
                    occurrences are repeats of material already paid
                    for — these are measurements taken by reading
                    the cut

  This is a real limit of a spreadsheet, not a shortcut. To know
  whether the same source frames appear twice you have to compare the
  ranges of every clip of that archive against each other, partial
  overlaps included. A formula can add up; it cannot recognise. So
  those values arrive from the Calculator as established facts,
  written into cells the sheet does not recompute.

  In practice: editing a segment's timecodes by hand in the Segments
  sheet does NOT change the cost, and deleting or adding segment rows
  does not produce a consistent count. When the cut changes, run the
  Calculator again and re-export.

  The workbook is for negotiating rates, not for correcting the cut.


THE MONITOR
-----------
A small floating window you leave open next to the timeline: one line
per archive, with the total duration used and how many video and
audio segments it comes from.

No rounding, no discounts, no invoice — just the durations, updated
when you press Refresh. It answers the question you ask yourself
twenty times a day: how much of this archive am I using?

Click an archive name and every clip from it is flagged and selected
in the timeline, so you can see where that material sits in the cut.

The checkbox shows or hides the Photos and Newspapers archives.


SAVED SETS  (the "Saved sets" tab in Config)
---------------------------------------------
Snapshots of your whole archive database, saved under a name you
choose. Load one and the current configuration is replaced.

The configuration you had before a load is kept automatically, and
"Restore previous" brings it back.

This is the safe way to set up a throwaway configuration — for a
demo, or for a project with different rates — without losing your
real one.


IMPORT AND EXPORT OF THE ARCHIVE DATABASE
------------------------------------------
"Export CSV" in Config writes your archive list to a CSV that can be
re-imported, into your copy or anyone else's.

"Import JSON/CSV..." reads it back, and asks how:

  Add new            skips entries whose name already exists
  Update existing    overwrites entries with the same name
  Replace all        clears the database and re-imports

The Model column uses the stored values ("A clip", "Al minuto"), for
the reason explained under INTERFACE LANGUAGE. The English labels are
also accepted on import, so a file filled in while looking at the
English interface still works.

KNOWN LIMIT: the CSV format does not carry the Minimum usage field.
Exporting and re-importing a database LOSES the minimum usage values.
Set them again by hand afterwards, or use a saved set instead of CSV
when you want a faithful copy.


LOG FILE
--------
  macOS  : ~/Library/Logs/RepertoireDB/repertoire_db.log
  Windows: %LOCALAPPDATA%\\Blackmagic Design\\DaVinci Resolve\\
           Logs\\RepertoireDB\\

Attach it to a bug report. The 🐛 button in each window opens a
pre-filled email with your system details; it shows you what it is
about to send before sending it.


IF SOMETHING GOES WRONG
-----------------------
"module 'LogManager' not found"
    The shared modules are not in Fusion/Modules/Lua. This is the one
    mistake almost everyone makes. See INSTALLING BY HAND.

The script menu entry does nothing, or no window appears
    You are on the free version of DaVinci Resolve. See REQUIREMENTS.

"openpyxl is not installed"
    Excel export needs Python 3 with openpyxl. Run
    RepertoireDB_Installer.lua, or install it yourself with
    pip3 install openpyxl. CSV export works without it.

The interface is in Italian although my system is in English
    Strings.lua is missing from Fusion/Modules/Lua. The tool works
    without it; only the translation is absent.

Costs look too high on a timeline with many repeated shots
    Check that the repeats are marked "REUSED" in the breakdown. If
    they are not, the clips are probably different source files
    rather than the same one used twice.


A NOTE ON THE NUMBERS
---------------------
The report is a working estimate, not the production's official
costing. Contractual terms vary and always take precedence.

These scripts are written by a working film editor, not a
professional developer. The code works and is used on real
productions, but do not expect the conventions of a software project.
