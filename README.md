# Quire

A Mac app for reading and highlighting PDFs, reorganising their pages, and making scans
searchable. An iPhone and iPad version reads, highlights and reorganises, but does not
recognise text.

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

macOS 27 for the Mac app, iOS 27 for the iPhone and iPad app, and Xcode 27 to build both.
The only third-party dependency is Sparkle, which installs updates on the Mac. PDFKit and
Vision ship with the system.

## Building

The Xcode project is generated from `project.yml` using `xcodegen` and is not committed.
Release builds read the Apple development team, the updates host and the Sparkle public key
from `Config/Release.xcconfig`, which is not committed either. Copy
`Config/Release.xcconfig.example` and fill it in.

Generate the project first, and again whenever a file is added or removed:

```bash
xcodegen generate
open Quire.xcodeproj
```

Then press Run. From the command line:

```bash
xcodebuild -project Quire.xcodeproj -scheme Quire-macOS -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Quire.app
```

## Releasing

### iPhone and iPad: beta through TestFlight

TestFlight is Apple's app for installing beta versions.

**Setup**

1. **Join the Apple Developer Program** -- already done on this Mac, along with signing in to the account in Xcode
2. **Create the app record** -- add Quire in App Store Connect, Apple's website for managing apps, with the bundle ID `com.mashoaib.quire`

**Every beta**

1. Raise the version and build number in `project.yml`. App Store Connect turns down any build number that isn't higher than every earlier upload
2. In Xcode, choose the `Quire-iOS` scheme and **Any iOS Device**, then **Product -> Archive**
3. When the archive appears in the Organizer, choose **Distribute App -> TestFlight**
4. Wait for Apple to process the build, and it appears in App Store Connect
5. Give testers access to the build
6. Testers install it from the TestFlight app on their iPhone or iPad

### Mac: DMG from any website

**Setup**

All of these are already set up on this Mac.

1. **Create a Developer ID certificate** -- this shows Macs the app came from you
2. **Store the notarization login** -- this lets the script send the app to Apple for scanning. Quire uses the login stored as `notary`
3. **Generate the Sparkle key** -- this proves that updates really came from you. Quire uses the key already in the keychain
4. **Get a website address** -- this is where the DMG and update file will live. Set it as `QUIRE_UPDATES_HOST` in `Config/Release.xcconfig`

**Release**

1. Raise the version and build number in `project.yml`
2. Run `scripts/release-mac.sh`. It does all of this for you:
   - builds and signs the app
   - puts it in a DMG
   - gets Apple to scan it
   - updates `appcast.xml`, the file that tells installed apps what the latest version is
3. Upload the new DMG and `appcast.xml` from `releases/` to your website

**What people do**

1. They download the DMG from your website
2. They open it and drag Quire into Applications
3. From then on, the app checks `appcast.xml` by itself and offers new versions as you release them. They can also use **Check for Updates…** in the Quire menu

## Decisions worth knowing

**AppKit, not a SwiftUI `DocumentGroup`.** SwiftUI's document scene always autosaves in
place, with no way to turn it off, so editing a PDF would silently rewrite the original
file. Quire uses `NSDocument` with `autosavesInPlace` false, so edits stay in memory until
you save, and closing or quitting with unsaved work prompts. The views are still SwiftUI,
hosted in an AppKit window.

**The app is not sandboxed.** The sandbox was turned off for a feature that has since been
removed, which merged the other PDFs in a file's folder into it. A sandboxed app can only
touch the files the user picked, and that feature needed the whole folder. Nothing needs
that now, and the sandbox has not been turned back on. The Mac app is released as a DMG
rather than through the App Store, and only the App Store requires the sandbox.

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

**The icon is a Q made of lines of text.** The bottom three lines run past the circle and
turn the highlighter's yellow, which makes the Q's tail. The app icon is the Icon Composer
file `Icon/AppIcon.icon`, built from flat layers. The PDF document icon shows the same Q on
a page. `Tools/make-document-icon.swift` draws it into `macOS/DocumentIcon.icns`, so edit
the script, run `swift Tools/make-document-icon.swift`, and rebuild.

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

**Where a PDF was closed is kept on the PDF's file, beside its contents.**
`ReadingPositions.swift` writes each position as an extended attribute, which is a small
labelled note macOS keeps with a file rather than inside it. The note follows the file
when it is moved or renamed, and a different PDF put at the same path has none. The
contents are never written to, so other readers see no change. A list in the app's
preferences, filed under each PDF's path, was tried first. It lost the position on a
rename, and would have handed it to whatever file took over the path.

**The position is saved on quitting as well as on closing a tab.** AppKit does close each
document while quitting, but only as the last thing it does on its way out.
`applicationWillTerminate` saves the positions first, rather than rely on that.

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

