# Quire

A Mac app for reading and highlighting PDFs, reorganising their pages and making scans searchable.

Preview already reads PDFs and reorders pages but it can't add a text layer to a scan, so a scanned document stays unsearchable forever. That's the gap Quire fills, and the rest of the app is there so you don't have to leave it for the ordinary things. An iPhone and iPad version does all of it except recognising text.

## What it does

**Open** -- every PDF opens as a tab of one window, and a PDF you've opened before goes back to the spot and zoom it was closed on. A new tab lists the files you opened recently, which is also what you see when Quire starts with nothing to read.

**Read** -- continuous scrolling in a single or two-page layout with zoom from a pinch or from the rail down the right edge, which holds everything else you need while reading. A sidebar shows the pages as thumbnails or shows the PDF's table of contents with the section you're reading highlighted.

**Find** -- a panel over the document shows results as you type and lists them by the text that actually matched and how often, so a search that ignores case still shows each form it found.

**Highlight** -- select text and pick a colour from the small bar that appears beside it, then click a highlight later to recolour or remove it. Highlights are saved into the PDF so every other reader shows them, and the ones made elsewhere can be changed here too.

**Highlight mode** -- for highlighting a lot at once, where dragging across text highlights it straight away in the colour picked from a palette beside the rail and right-clicking a highlight removes it.

**Organise** -- a grid of page thumbnails where you drag pages into a new order, rotate or delete them and drop another PDF or an image in at any spot. Every edit can be undone.

**Recognise text** -- reads each page and writes the words back as an invisible layer over the scan, so the page looks the same but its text can now be selected and searched in every PDF reader. Pages that already have text are left alone and the whole run undoes as one step.

## How it works

**Saving** -- edits stay in memory until you save and closing with unsaved work asks first, so the original file is never rewritten behind your back.

**Reading positions** -- the spot a PDF was closed on is kept as a small note macOS stores with the file rather than inside it, so it follows the file when it's moved or renamed and other readers see no change.

**Recognising text** -- Apple's Vision does it all on the Mac, and since the first run after a restart can take up to a minute while macOS loads the model Quire warms it up at launch.

**What reaches the internet** -- only the Mac app's check for updates.

## Requirements

- **macOS 27** -- for the Mac app
- **iOS 27** -- for the iPhone and iPad app
- **Xcode 27** -- to build both
- **Sparkle** -- installs updates on the Mac and is the only third-party dependency

## Building

The Xcode project is generated from `project.yml` using `xcodegen` and isn't committed, and neither is `Config/Release.xcconfig` which holds the Apple development team, the updates host and the Sparkle public key for release builds. Make it by copying `Config/Release.xcconfig.example` and filling it in.

To try a change type `go` anywhere in this repo and pick Rebuild to:

1. Build Quire in Release for the Mac and for the iPhone and iPad simulators
2. Quit the running Mac app and install the new build in `/Applications`
3. Reopen it and restart the iPhone and iPad apps from the new build

If either build fails nothing running is touched.

The `go` command, its menu and its scripts all come from a private repo shared by all my apps, and the menu needs [gum](https://github.com/charmbracelet/gum) which the private repo installs.

## Releasing

The Mac app is released as a DMG from its own website and updates itself through Sparkle, and the iPhone and iPad app goes out as a beta through TestFlight.
