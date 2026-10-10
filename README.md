# Quire

A Mac app for reading and highlighting PDFs, reorganising their pages, and making scans
searchable.

Preview already reads PDFs and reorders pages. What it cannot do is add a text layer to a
scan, so a scanned document stays unsearchable forever. That is the gap Quire fills, and
the rest of the app exists so you do not have to leave it to do the ordinary things.

## What it does

**Open.** Every PDF opens as a tab of one window, and the plus at the end of the tab bar
opens a tab listing recently opened files, which is also what you get when Quire is
launched with nothing to read. A PDF that has been open before goes back to the spot it
was closed on, and to the zoom it had if you had changed it.

**Read.** Continuous scrolling, single or two-page layout, and zoom by pinch or from the
rail down the right edge, which also holds the page number, text recognition, highlight
mode, find, the fit modes and the switch between reading and organising. A thumbnail
sidebar sized by its own slider, where pages can be dragged into a new order, hovering a
page reveals rotate and delete, and hovering between pages reveals a plus that inserts a
PDF or an image there. A button on the rail swaps the thumbnails for the PDF's table of contents, where
clicking a title jumps to that section. The section being read is highlighted, and the
chapter around it opens as you reach it. Scans have no table of contents, and say so. A
PDF with a table of contents opens on it, and any other opens on its thumbnails. The
sidebar keeps its size when you switch, and the slider sizes it on either side.

**Find.** Cmd-F, or the rail's magnifying glass, opens a panel over the document. Results
appear as you type, listed by the text that actually matched and how often, so a
case-insensitive search names each form it found rather than merging them.

**Highlight.** Select text and a small bar of colour dots appears beside it. Clicking a dot
highlights the selection in that colour, and the colour used last comes first the next
time. Clicking a highlight brings the bar back, where the dots recolour it and the trash
removes it. Highlights are saved into the PDF, so every other PDF reader shows them, and
the ones made elsewhere can be recoloured and removed here. Each change undoes with Cmd-Z.
A scan needs its text recognised first, since there is nothing to select before that.

**Highlight mode.** The rail's highlighter turns it on, for highlighting a lot at once.
Dragging across text highlights it on release, with no bar in between. A palette of the
five colours stands beside the rail for as long as the mode is on, with a ring around the
one in use, and the colour can be changed between drags. Its dots keep one order, unlike
the bar's. Right-clicking a highlight removes it. The mode belongs to its tab, and the
colour is the same one the bar remembers.

**Organise.** A grid of page thumbnails, which opens on the page you were reading, already
selected as though you had clicked it. Drag to reorder, drag a marquee across empty space
to select a run of pages, and hover any page for rotate and delete. Those act on the whole
selection when the page you are pointing at belongs to it. Hover between pages for a plus
that inserts another PDF or an image at that exact spot, or drop either from Finder anywhere
in the grid. An image becomes a page of its own. Every edit undoes with Cmd-Z.

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

## Releasing

Push a version tag to publish a release:

```bash
git tag v1.1
git push origin v1.1
```

GitHub then builds `Quire.app` and attaches it as `Quire.zip` to a release for that tag.
The app's version is the tag's number without the `v`. The `MARKETING_VERSION` build
setting is only what a local build reports. The workflow is `.github/workflows/release.yml`.

On a Mac set up with [workshop](https://github.com/emaishoaib/workshop), the next
`setup.sh` run replaces the installed Quire with the new release. That copy is downloaded
with curl, which does not quarantine it, so it opens without the step below.

## Giving someone a copy

Send them the [latest release](https://github.com/emaishoaib/quire/releases/latest). They
download `Quire.zip` from it, unzip it and move Quire to Applications.

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

**The app is not sandboxed.** The sandbox was turned off for a feature that has since been
removed, which merged the other PDFs in a file's folder into it. A sandboxed app can only
touch the files the user picked, and that feature needed the whole folder. Nothing needs
that now, and the sandbox has not been turned back on. The app is signed ad-hoc and never
goes near the App Store, so the sandbox was protecting little.

**An inserted image keeps its own size.** Its page is the size the file states for print,
which is its pixels divided by its dots per inch, as in Preview. A photo can therefore land
as a page much larger than the ones around it. A photo taken upright arrives upright,
because the camera's note about which way is up becomes the page's rotation.

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

**The table of contents is built from disclosure groups, not `List(_:children:)`.** The
list's own form keeps which entries are expanded to itself, so nothing outside it can open
the chapter around the section being read. `ContentsSidebar.swift` keeps the expanded
entries in a set of its own instead. Its rows also respond to a tap rather than to the
list's selection, because clicking the section already selected would not change the
selection, and so would not jump back to the section's start.

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

**Where a PDF was closed is kept in the app's preferences, not in the PDF.**
`ReadingPositions.swift` files each position under the PDF's path, so the file itself is
never written to. A PDF that is moved or renamed therefore opens on its first page, as one
never opened before.

**The position is saved on quitting as well as on closing a tab.** AppKit does close each
document while quitting, but as the last thing it does, and a position saved that late did
not reach the preferences file when tried. `applicationWillTerminate` saves them first.

**The zoom is remembered only once you have changed it.** A PDF left at the fit it opened
with is fitted to the window's height again next time, at whatever size the window is
then. Restoring a number instead would leave it wrong for a window of another size.

**A remembered spot is put back after each resize while the window opens.** The window
changes size several times on its way to the screen, and each change moves the scroll
position. `ViewerController` holds the spot until you first change the zoom, the same way
it holds the opening fit to height.

**Settings that drive animation use `.animation(_:value:)`, not `withAnimation`.** The
sidebar toggle and the thumbnail size are `@AppStorage`, so the new value comes back from
UserDefaults outside whatever transaction set it, and an animation wrapped around the
change is simply lost. Both are animated from the container that holds them, keyed to the
setting. The sidebar's tab is plain window state, since each PDF picks its own, but it is
animated the same way, from a container that holds the rail as well as the sidebar, so
that the rail's icon animates too.

**Page edits animate because pages are identified by object.** `PageGrid` and
`ThumbnailSidebar` list `document.pages`, whose elements survive a reorder, and
`applyPages` wraps its change in a spring. Adding `.id(document.revision)` to either view
to "force a refresh" would tell SwiftUI to rebuild from scratch and kill every animation.

**A highlight is a PDF annotation, and making one does not bump `revision`.** The
annotation is what the PDF format itself stores for a highlight, which is why other readers
show it. The page list is untouched, and the Read view redraws an annotated page by itself.
Bumping `revision` would reload the view and clear any search. A highlight is one
annotation for each page it touches, listing the corners of every line, so several lines
stay one highlight that is recoloured and removed together.

**The highlight bar is placed in `ViewerController.swift`, from the first and last lines of
the selection.** The selection's overall bounds would centre the bar on the widest line
rather than where the selection starts. The bar appears when the mouse is released, which
`FittingPDFView` reports. It then follows the selection for a moment, because PDFKit can go
on settling a selection after the release. A selection made from code, such as the current
find match, gets no bar.

**A right click is acted on once, though PDFKit asks for its menu twice.** It asks from the
page under the mouse and again from the view. `FittingPDFView` remembers the click it has
dealt with. Without that, a right click in highlight mode on two highlights lying one over
the other would remove both.

**The palette is drawn by the window, not by the rail.** It reaches out over the document,
which the rail's bounds do not cover. The rail reports where its highlight button is, and
`ContentView.swift` places the palette level with it.

**A drag in highlight mode is highlighted by the window, not by `ViewerController`.** The
controller knows when a drag ends, but the document and the colour belong to the window.
The controller counts the drags and the window watches the count, the same arrangement as
asking for Find a second time.

**Highlights are paler than the dots that pick them.** `HighlightColour` carries two shades
of each colour. The dots are full strength so they stand apart at their small size, and
that strength is heavy behind whole lines of text.

**Recolouring takes the highlight off its page and puts it back.** Removing and adding an
annotation is what the Read view is known to redraw for. Whether it also redraws for a
colour changed in place was not tested, so the change is wrapped in the pair that is.

## Open questions

**Thumbnails do not show a highlight until the file is reopened.** `ThumbnailCache` keeps a
page's image until the page or its rotation changes, and a highlight changes neither. The
fix is to drop a page's image when its highlights change, which nothing does yet.

**PDFs show a preview of page one rather than Quire's document icon.** Finder prefers a
generated preview over a handler's icon when it can make one, and turning off "Show icon
preview" in Finder's view options reveals ours. Acrobat manages to show its own icon
anyway; the likely reason is a QuickLook thumbnail extension, which we would have to write
one of to match. Setting `LSHandlerRank` to `Owner` was tried and made no difference, so it
is back to `Alternate`.

