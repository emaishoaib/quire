# Quire

A Mac app for reading PDFs, reorganising their pages, and making scans searchable.

Preview already reads PDFs and reorders pages. What it cannot do is add a text layer to a
scan, so a scanned document stays unsearchable forever. That is the gap Quire fills, and
the rest of the app exists so you do not have to leave it to do the ordinary things.

## What it does

**Open.** Every PDF opens as a tab of one window, and the plus at the end of the tab bar
opens a tab listing recently opened files, which is also what you get when Quire is
launched with nothing to read.

**Read.** Continuous scrolling, single or two-page layout, and zoom by pinch or from the
rail down the right edge, which also holds the page number, text recognition, renaming,
merging, find, the fit modes and the switch between reading and organising. A thumbnail
sidebar sized by its own slider, where pages can be dragged into a new order, hovering a
page reveals rotate and delete, and hovering between pages reveals a plus that inserts
there.

**Find.** Cmd-F, or the rail's magnifying glass, opens a panel over the document. Results
appear as you type, listed by the text that actually matched and how often, so a
case-insensitive search names each form it found rather than merging them.

**Organise.** A grid of page thumbnails. Drag to reorder, drag a marquee across empty space
to select a run of pages, and hover any page for rotate and delete. Those act on the whole
selection when the page you are pointing at belongs to it. Hover between pages for a plus
that inserts another PDF at that exact spot, or drop a PDF from Finder anywhere in the grid.
Every edit undoes with Cmd-Z.

**Recognise text.** Vision reads each page and Quire writes the words back as an invisible
text layer over the scan. The page looks identical, but the text is now selectable and
searchable, in Quire and in every other PDF reader. Pages that already have text are left
alone. The whole run undoes as one action.

**Rename.** The rail's pencil works out how the other PDFs in the folder are named, and
suggests a name for this one in the same pattern. The date, the period and the amount are
read out of the document, each chosen by the label printed just before it. The free text
is taken from the names already in the folder, by which one's words the document contains.
The suggestion lands in a field you can edit before renaming, and anything that could not
be read is left as a placeholder to fill in. A scan needs its text recognised first. The
button is greyed out when the folder has no pattern, and hovering it says so.

**Merge.** The rail's merge button gathers the PDFs in the same folder whose names are this
file's name with something added, so `Lease.pdf` gathers `Lease 2.pdf`, `Lease-signed.pdf`
and `Lease (1).pdf`, but not `Leasehold.pdf`. After you confirm the list, their pages are
added to the end in Finder's order, the PDF is saved, and the gathered files go to the
Trash. The button is greyed out when there is nothing to gather.

**Folder access.** Renaming and merging both read the folder the PDF is in, not only the
PDF itself. Opening a PDF lets Quire read that one file, and macOS protects folders such
as Documents, Desktop, Downloads and iCloud Drive separately. When Quire is not allowed
into the folder, the rename and merge buttons stay clickable and explain this, with a
button that opens Files and Folders in Privacy & Security. Once Quire is allowed in there,
switching back to Quire is enough for both buttons to work.

## Requirements

macOS 27 and Xcode 26. No third-party dependencies: PDFKit and Vision ship with macOS.

## Building

```bash
open Quire.xcodeproj
```

Then press Run. From the command line:

```bash
xcodebuild -project Quire.xcodeproj -scheme Quire -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Quire.app
```

## Giving someone a copy

The app is signed ad-hoc, which means the signature proves the app has not been tampered
with but does not say who made it. macOS therefore blocks the first launch of a copy that
arrived from elsewhere. **Tell whoever you send it to: right-click Quire and choose Open,
then click Open in the dialog.** Double-clicking first gives a message with no way
forward. After that one time, it launches normally on that machine.

Renaming and merging on that machine also need Quire allowed into the folders the PDFs are
in, under Files and Folders in Privacy & Security. The buttons explain this when it is
missing.

Building from source avoids that entirely, since locally built apps are not quarantined.

Paying for an Apple Developer Program membership would remove that step, by allowing a
Developer ID signature and notarisation. It is not worth it for a couple of machines.

## Decisions worth knowing

**AppKit, not a SwiftUI `DocumentGroup`.** SwiftUI's document scene always autosaves in
place, with no way to turn it off, so editing a PDF would silently rewrite the original
file. Quire uses `NSDocument` with `autosavesInPlace` false, so edits stay in memory until
you save, and closing or quitting with unsaved work prompts. The views are still SwiftUI,
hosted in an AppKit window.

**The app is not sandboxed.** A sandboxed app can only touch the files the user picked, so
Quire could open `Lease.pdf` but never see `Lease 2.pdf` beside it, let alone move it to the
Trash. Merging needs the whole folder. Asking for folder access through an Open panel would
keep the sandbox, but the app is signed ad-hoc and never goes near the App Store, so the
sandbox was protecting little.

**Merged files are trashed only after the save succeeds.** Trashing first would leave their
pages existing only in memory until the save, and a failed save would lose them from disk.

**Renaming uses no language model.** An earlier version asked Apple's on-device model to
read the document. `NameReader.swift` replaced it with plain code, so renaming works on any
Mac, the same document always gets the same suggestion, and there is no question of where
a document's text goes. The cost is a sender the folder has not seen before, which is left
as a placeholder to type once. After that, the folder's names include it.

**The app is started by hand in `AppDelegate.swift`.** `@main` on an AppKit delegate class
expects a MainMenu nib to create the delegate, and this app has no nibs. Without the
explicit `main()`, the delegate is never created, the menu bar never appears, and every
menu shortcut silently fails.

**`minimumTextHeightFraction` is zero in `OCREngine.swift`.** Vision's default skips text
below a fraction of the image height, which on a test scan lost every table row and turned
"5GB" into "SGB". It is not a stray line to clean up.

**OCR draws one invisible word at a time, each with a trailing space.** A whole line
stretched to fit drifts sideways, because the scanned font is a different width from ours,
so highlights land off the words. Without the trailing spaces, PDFKit guesses word
boundaries from gaps and produces "12in".

**Vision is warmed up at launch.** The first text recognition after a restart can take up
to a minute while macOS loads the model. `OCRRunner.warmUp()` pays that cost in the
background at launch, and the progress sheet says so if you get there first.

**The icon is generated.** `Tools/make-icon.swift` draws both the app icon and the PDF
document icon, and writes every size into the asset catalogue. Edit the script, run
`swift Tools/make-icon.swift`, and rebuild.

**The thumbnail sidebar is hand-written SwiftUI, not `PDFThumbnailView`.** PDFKit's view
highlights the current page and follows the scroll position for nothing, and both are
reimplemented in `ThumbnailSidebar.swift`. The reason is that a single AppKit view cannot
give individual pages their own hover controls, which is what the rotate, delete and insert
buttons need.

**The window has no toolbar, and the controls live in a rail.** Two reasons. SwiftUI
toolbars hosted in an AppKit window ignore trailing placement, so items land at the far
left however they are declared. More importantly, a window without a toolbar shows its
tabs in the title bar rather than in a row of their own, which is where the file names
belong.

**Windows are added to the tab group explicitly, in `WindowTabs.swift`.** macOS merges
document windows into tabs by itself only when the user has chosen that in System
Settings, so relying on it would work on one Mac and not another. The same file forces the
tab bar to stay visible, which macOS otherwise hides below two tabs, taking the plus
button with it.

**Every window shares one saved frame.** Documents and start screens save and restore under
the name `QuireWindow`, so a new tab is the size you last left. Note that
`setFrameAutosaveName` only says where to save: restoring needs `setFrameUsingName`, and
leaving that out is why every window used to open at its coded size.

**A start tab closes when a document opens in that window.** The start screen exists to
open something, so it is replaced rather than joined, however the file was opened.

**Settings that drive animation use `.animation(_:value:)`, not `withAnimation`.** The
sidebar toggle and the thumbnail size are `@AppStorage`, so the new value comes back from
UserDefaults outside whatever transaction set it, and an animation wrapped around the
change is simply lost. Both are animated from the container that holds them, keyed to the
setting.

**Page edits animate because pages are identified by object.** `PageGrid` and
`ThumbnailSidebar` list `document.pages`, whose elements survive a reorder, and
`applyPages` wraps its change in a spring. Adding `.id(document.revision)` to either view
to "force a refresh" would tell SwiftUI to rebuild from scratch and kill every animation.

## Open questions

**PDFs show a preview of page one rather than Quire's document icon.** Finder prefers a
generated preview over a handler's icon when it can make one, and turning off "Show icon
preview" in Finder's view options reveals ours. Acrobat manages to show its own icon
anyway; the likely reason is a QuickLook thumbnail extension, which we would have to write
one of to match. Setting `LSHandlerRank` to `Owner` was tried and made no difference, so it
is back to `Alternate`.

