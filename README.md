# Quire

A Mac app for reading PDFs, reorganising their pages, and making scans searchable.

Preview already reads PDFs and reorders pages. What it cannot do is add a text layer to a
scan, so a scanned document stays unsearchable forever. That is the gap Quire fills, and
the rest of the app exists so you do not have to leave it to do the ordinary things.

## What it does

**Read.** Continuous scrolling, single or two-page layout, and zoom by pinch or from the
rail down the right edge, which also holds the page number, text recognition and the fit
modes. A thumbnail sidebar sized by its own slider, where hovering a page reveals rotate
and delete and hovering between pages reveals a plus that inserts there. Search across the
document with the matches highlighted and counted.

**Organise.** A grid of page thumbnails. Drag to reorder, drag a marquee across empty space
to select a run of pages, and hover any page for rotate and delete. Those act on the whole
selection when the page you are pointing at belongs to it. Hover between pages for a plus
that inserts another PDF at that exact spot, or drop a PDF from Finder anywhere in the grid.
Every edit undoes with Cmd-Z.

**Recognise text.** Vision reads each page and Quire writes the words back as an invisible
text layer over the scan. The page looks identical, but the text is now selectable and
searchable, in Quire and in every other PDF reader. Pages that already have text are left
alone. The whole run undoes as one action.

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

Building from source avoids that entirely, since locally built apps are not quarantined.

Paying for an Apple Developer Program membership would remove that step, by allowing a
Developer ID signature and notarisation. It is not worth it for a couple of machines.

## Decisions worth knowing

**AppKit, not a SwiftUI `DocumentGroup`.** SwiftUI's document scene always autosaves in
place, with no way to turn it off, so editing a PDF would silently rewrite the original
file. Quire uses `NSDocument` with `autosavesInPlace` false, so edits stay in memory until
you save, and closing or quitting with unsaved work prompts. The views are still SwiftUI,
hosted in an AppKit window.

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

**The read controls float in a rail rather than sitting in the toolbar.** SwiftUI toolbars
hosted in an AppKit window ignore trailing placement, so toolbar items land at the far left
however they are declared. The rail sidesteps that and keeps the controls beside what they
act on.

## Open questions

**PDFs show a preview of page one rather than Quire's document icon.** Finder prefers a
generated preview over a handler's icon when it can make one, and turning off "Show icon
preview" in Finder's view options reveals ours. Acrobat manages to show its own icon
anyway; the likely reason is a QuickLook thumbnail extension, which we would have to write
one of to match. Setting `LSHandlerRank` to `Owner` was tried and made no difference, so it
is back to `Alternate`.

**Drag-to-reorder in the sidebar is deliberately absent.** The Pages grid has it, but in
the sidebar a drag would compete with click-to-navigate, so the sidebar stays a navigation
and single-page-editing surface, and reordering lives in Pages mode.
