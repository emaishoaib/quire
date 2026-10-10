//
//  ViewerController.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// Drives the live `PDFView` on behalf of SwiftUI.
///
/// SwiftUI recreates the view wrapper freely, so the reference to the AppKit view
/// is held here instead, where it survives those rebuilds.
@Observable
final class ViewerController {

    /// How the rail's find control changes shape, and how the match count rolls over.
    ///
    /// The animation is applied where the values change rather than in the view: a view
    /// appearing or disappearing is not covered by `animation(_:value:)` on the view
    /// itself, so without this the swap happens instantly.
    static let searchAnimation = Animation.spring(duration: 0.32, bounce: 0.2)

    private(set) var matches: [PDFSelection] = []
    private(set) var matchIndex = 0
    private(set) var currentPage = 0
    private(set) var scale = 1.0
    private(set) var isTwoUp = false
    private(set) var isContinuous = true
    private(set) var showsCoverPage = false
    private(set) var attachCount = 0

    /// True while highlight mode is on, in which dragging across text highlights it.
    private(set) var isHighlighting = false

    /// Counts the drags released in highlight mode, each one a request to highlight
    /// what it selected.
    ///
    /// The controller knows when a drag ends, but the document and the colour to highlight
    /// in belong to the window. The window watches this count and does the highlighting,
    /// the way the find panel watches the count of requests for it.
    private(set) var highlightRequests = 0

    /// Where the highlight bar should sit, while it is showing.
    ///
    /// That is beside the selected text, or beside `selectedHighlight` when there is one.
    private(set) var selectionAnchor: SelectionAnchor?

    /// The highlight the bar is showing for, when clicking one is what opened it.
    private(set) var selectedHighlight: Highlight?
    var matchCase = false

    @ObservationIgnored private weak var view: PDFView?
    @ObservationIgnored private var lastQuery = ""
    @ObservationIgnored private var pendingPage: Int?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var pulse: Task<Void, Never>?
    @ObservationIgnored private var snapshot: Snapshot?

    /// Where the PDF was scrolled to when it was last closed, until the view has gone there.
    @ObservationIgnored private var openingPosition: ReadingPosition?

    /// True from a document opening until the user first changes the zoom.
    ///
    /// The window is resized several times while it opens, first at its minimum size, so
    /// the opening fit to height is redone on each resize until the user takes over.
    @ObservationIgnored private var keepsHeightFitted = false

    /// True from a document opening at its remembered zoom until the user first changes it.
    ///
    /// Each resize the window makes while it opens moves the scroll position, so the
    /// remembered spot is put back after every one until the user takes over.
    @ObservationIgnored private var keepsOpeningSpot = false

    /// The scale last set from code, to tell a pinch-zoom apart from a refit.
    @ObservationIgnored private var appliedScale: CGFloat = 1

    /// True while code is setting the scale.
    ///
    /// PDFKit posts its scale notification from inside the assignment, before
    /// `appliedScale` can be updated, so the pinch check has to sit that one out.
    @ObservationIgnored private var isApplyingScale = false

    /// True from the mouse being released over the view until the highlight bar is dismissed.
    ///
    /// PDFKit can go on settling a selection for a moment after the mouse is released, so
    /// the bar follows the selection's changes while this is set. A selection made from
    /// code, such as the current find match, arrives while it is clear and gets no bar.
    @ObservationIgnored private var followsSelection = false

    /// What the Read view was showing when it was torn down, for the next one to pick up.
    private struct Snapshot {
        let scale: CGFloat
        let autoScales: Bool
        let destination: PDFDestination?
    }

    init(openingPosition: ReadingPosition? = nil) {
        self.openingPosition = openingPosition
    }

    /// The live view, for the thumbnail sidebar to hand itself to.
    var attachedView: PDFView? { view }

    /// Where the PDF is scrolled to and how far it is zoomed, for remembering once it is closed.
    ///
    /// A view torn down for Pages leaves both in the snapshot, and the view that replaces
    /// it has not taken them up until its first layout, so the snapshot is believed over
    /// the view for as long as there is one.
    ///
    /// The zoom is left out while the PDF is still at the fit it opened with.
    ///
    /// A tab that has never been shown has no view that has laid out, so the position
    /// it was opened with is handed back unchanged rather than lost to the first page.
    var position: ReadingPosition? {
        if let openingPosition {
            return openingPosition
        }
        guard let destination = snapshot?.destination ?? view?.currentDestination else { return nil }
        let scale = keepsHeightFitted ? nil : snapshot?.scale ?? view?.scaleFactor
        return ReadingPosition(destination, scale: scale.map(Double.init))
    }

    /// Ends the opening fit or hold, because the user has chosen a zoom of their own.
    private func zoomWasChosen() {
        keepsHeightFitted = false
        keepsOpeningSpot = false
    }

    /// Takes hold of a newly created view and restores what the old one was showing.
    ///
    /// Switching between Read and Pages destroys the view. The page layout and search
    /// highlights are applied here. The zoom and scroll position wait for
    /// `viewDidFirstLayout`, because they need the view to have a size.
    func attach(_ view: PDFView) {
        self.view = view
        attachCount += 1
        applyDisplayMode()
        view.displaysAsBook = showsCoverPage
        if !matches.isEmpty {
            view.highlightedSelections = matches
        }
        observeChanges(of: view)
    }

    /// Remembers what the view is showing before SwiftUI tears it down.
    func detach(_ view: PDFView) {
        guard view === self.view else { return }
        snapshot = Snapshot(
            scale: view.scaleFactor,
            autoScales: view.autoScales,
            destination: view.currentDestination
        )
        hideHighlightBar()
    }

    /// Republishes PDFKit's page and zoom changes as observable state.
    ///
    /// `PDFView` tracks the current page and scale privately and only posts notifications
    /// about them, so the page indicator and the zoom percentage have nothing to read
    /// without this, and would go stale the moment the user scrolled or pinch-zoomed.
    private func observeChanges(of view: PDFView) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = [.PDFViewPageChanged, .PDFViewScaleChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.syncFromView()
                }
            }
        }
        observers += [Notification.Name.PDFViewScaleChanged, .PDFViewDisplayModeChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.hideHighlightBar()
                }
            }
        }
        observers.append(
            NotificationCenter.default.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.selectionDidChange()
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: .main) { [weak self] note in
                let scrolled = note.object as? NSClipView
                MainActor.assumeIsolated {
                    self?.viewDidScroll(scrolled)
                }
            }
        )
        syncFromView()
    }

    private func syncFromView() {
        guard let view else { return }
        if !isApplyingScale && view.scaleFactor != appliedScale {
            zoomWasChosen()
        }
        if let page = view.currentPage, let document = view.document {
            currentPage = document.index(for: page)
        }
        scale = view.scaleFactor
        isTwoUp = view.displayMode == .twoUp || view.displayMode == .twoUpContinuous
        isContinuous = view.displayMode == .singlePageContinuous || view.displayMode == .twoUpContinuous
        showsCoverPage = view.displaysAsBook
    }

    func setTwoUp(_ twoUp: Bool) {
        isTwoUp = twoUp
        applyDisplayMode()
    }

    func setContinuous(_ continuous: Bool) {
        isContinuous = continuous
        applyDisplayMode()
    }

    /// Leaves the first page on its own, the way a book's cover sits alone.
    func setShowsCoverPage(_ showsCover: Bool) {
        showsCoverPage = showsCover
        view?.displaysAsBook = showsCover
    }

    private func applyDisplayMode() {
        guard let view else { return }
        view.displayMode = switch (isTwoUp, isContinuous) {
        case (false, false): .singlePage
        case (false, true): .singlePageContinuous
        case (true, false): .twoUp
        case (true, true): .twoUpContinuous
        }
    }

    func setScale(_ factor: Double) {
        zoomWasChosen()
        applyScale(factor)
    }

    private func applyScale(_ factor: Double) {
        guard let view else { return }
        view.autoScales = false
        isApplyingScale = true
        view.scaleFactor = factor
        isApplyingScale = false
        appliedScale = view.scaleFactor
        syncFromView()
    }

    /// Fits the whole page in the window, and keeps doing so as the window resizes.
    func fitPage() {
        zoomWasChosen()
        view?.autoScales = true
        syncFromView()
    }

    /// Fits the page's width to the window, which PDFKit has no built-in setting for.
    func fitWidth() {
        guard let size = displayedPageSize, let view, size.width > 0 else { return }
        setScale((view.bounds.width - 24) / size.width)
    }

    /// Sets the zoom and scroll position, once the view has a size to fit against.
    ///
    /// A fresh document is fitted to the window's height. One that has been open before
    /// is scrolled to where it was last closed, at the zoom it had if the user chose one.
    /// A view rebuilt after visiting Pages goes back to where the old one was, unless a
    /// page was picked there.
    func viewDidFirstLayout() {
        guard let view else { return }
        if let snapshot {
            self.snapshot = nil
            if snapshot.autoScales {
                view.autoScales = true
            } else {
                setScale(snapshot.scale)
            }
            if let destination = snapshot.destination {
                view.go(to: destination)
            }
        } else {
            let opening = view.document.flatMap { openingPosition?.destination(in: $0) }
            let openingScale = openingPosition?.scale
            openingPosition = nil
            if let opening, let openingScale {
                setScale(openingScale)
                keepsOpeningSpot = true
                view.go(to: opening)
            } else {
                keepsHeightFitted = true
                applyHeightFit(keeping: opening ?? view.currentDestination)
            }
        }
        goToPendingPage()
    }

    /// Redoes the opening fit to height while the window is still settling, or puts a
    /// PDF opened at its remembered zoom back on its remembered spot.
    ///
    /// The highlight bar goes too, because the text it sat beside has moved.
    func viewDidResize(keeping top: PDFDestination?) {
        hideHighlightBar()
        if keepsHeightFitted {
            applyHeightFit(keeping: top)
        } else if keepsOpeningSpot, let top {
            view?.go(to: top)
        }
    }

    /// Fits the page's height to the window, the counterpart to `fitWidth`.
    func fitHeight() {
        zoomWasChosen()
        applyHeightFit(keeping: nil)
    }

    /// Fits the height, then scrolls `top` back to the top of the view if one is given.
    ///
    /// The page is fitted together with the gap PDFKit draws above and below it, which
    /// scales with the page. The page then fills the window and the next one starts
    /// exactly at the bottom edge, rather than showing a sliver of it.
    ///
    /// Changing the scale keeps PDFKit centred on roughly the same spot rather than on
    /// the top of the page, so without this the opening refits drift down the document.
    private func applyHeightFit(keeping top: PDFDestination?) {
        guard let size = displayedPageSize, let view, size.height > 0 else { return }
        let margins = view.pageBreakMargins
        let gap = view.displaysPageBreaks ? margins.top + margins.bottom : 0
        applyScale(view.bounds.height / (size.height + gap))
        if let top {
            view.go(to: top)
        }
    }

    /// The current page's size as shown, with width and height swapped for rotated pages.
    private var displayedPageSize: CGSize? {
        guard let view, let page = view.currentPage else { return nil }
        let bounds = page.bounds(for: view.displayBox)
        return page.rotation % 180 == 0
            ? bounds.size
            : CGSize(width: bounds.height, height: bounds.width)
    }

    func zoomIn() {
        zoomWasChosen()
        view?.zoomIn(nil)
        syncFromView()
    }

    func zoomOut() {
        zoomWasChosen()
        view?.zoomOut(nil)
        syncFromView()
    }

    func previousPage() {
        view?.goToPreviousPage(nil)
    }

    func nextPage() {
        view?.goToNextPage(nil)
    }

    /// Scrolls to a page, or remembers it until the view comes back.
    func goToPage(_ index: Int) {
        pendingPage = index
        goToPendingPage()
    }

    /// Scrolls to a spot on a page, such as where a section in the table of contents starts.
    ///
    /// Unlike `goToPage`, nothing is remembered when there is no view, because the table
    /// of contents is only shown beside a live one.
    func go(to destination: PDFDestination) {
        view?.go(to: destination)
    }

    private func goToPendingPage() {
        guard let view, let pendingPage, let page = view.document?.page(at: pendingPage) else { return }
        view.go(to: page)
        self.pendingPage = nil
    }

    /// Runs a search, replacing any results already on screen.
    ///
    /// Typing re-runs this on every keystroke, so it always starts from the first match
    /// rather than advancing, which is what `submitSearch` does when the query is unchanged.
    func search(_ query: String, in pdf: PDFDocument) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        lastQuery = query
        let found = pdf.findString(query, withOptions: matchCase ? [] : .caseInsensitive)
        for match in found {
            match.color = .systemYellow
        }
        withAnimation(Self.searchAnimation) {
            matches = found
            matchIndex = 0
        }
        view?.highlightedSelections = found.isEmpty ? nil : found
        showCurrentMatch()
    }

    /// The matched text grouped by what it actually says, with how often each form occurs.
    ///
    /// A case-insensitive search for "delivery" can match "Delivery" and "delivery", and
    /// the results list names each form rather than pretending they were identical.
    var matchGroups: [(text: String, count: Int, firstIndex: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var first: [String: Int] = [:]

        for (index, match) in matches.enumerated() {
            let text = match.string ?? ""
            guard !text.isEmpty else { continue }
            if counts[text] == nil {
                order.append(text)
                first[text] = index
            }
            counts[text, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0, first[$0] ?? 0) }
    }

    func goToMatch(_ index: Int) {
        guard matches.indices.contains(index) else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = index
        }
        showCurrentMatch()
    }

    /// Searches for `query`, or advances to the next match when the query is unchanged.
    func submitSearch(_ query: String, in pdf: PDFDocument) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            clearSearch()
            return
        }
        guard query != lastQuery || matches.isEmpty else {
            nextMatch()
            return
        }

        lastQuery = query
        matches = pdf.findString(query, withOptions: matchCase ? [] : .caseInsensitive)
        for match in matches {
            match.color = .systemYellow
        }
        matchIndex = 0
        view?.highlightedSelections = matches.isEmpty ? nil : matches
        showCurrentMatch()
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = (matchIndex + 1) % matches.count
        }
        showCurrentMatch()
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = (matchIndex - 1 + matches.count) % matches.count
        }
        showCurrentMatch()
    }

    func clearSearch() {
        pulse?.cancel()
        lastQuery = ""
        withAnimation(Self.searchAnimation) {
            matches = []
            matchIndex = 0
        }
        view?.highlightedSelections = nil
        view?.clearSelection()
    }

    /// Scrolls to the current match and flashes it.
    ///
    /// Every match is highlighted the same yellow, so landing on one is otherwise silent.
    /// The current match is drawn in a second colour, and flashes brighter for a moment
    /// when it is reached, which is what makes the jump visible on a crowded page.
    private func showCurrentMatch() {
        guard matches.indices.contains(matchIndex), let view else { return }
        let match = matches[matchIndex]

        hideHighlightBar()
        view.setCurrentSelection(match, animate: true)
        view.go(to: match)

        pulse?.cancel()
        pulse = Task { [weak self] in
            for colour in [NSColor.systemOrange, .systemOrange.withAlphaComponent(0.75), .systemPink] {
                guard !Task.isCancelled else { return }
                self?.paint(match, colour)
                try? await Task.sleep(for: .milliseconds(110))
            }
            guard !Task.isCancelled else { return }
            self?.paint(match, .systemPink)
        }
    }

    /// Repaints one match and hands the highlights back to the view to redraw them.
    private func paint(_ match: PDFSelection, _ colour: NSColor) {
        for other in matches where other !== match {
            other.color = .systemYellow
        }
        match.color = colour
        view?.highlightedSelections = matches
    }
}

extension ViewerController {

    /// Hides the highlight bar as a new click or drag begins.
    func mouseWentDown() {
        hideHighlightBar()
    }

    /// Turns highlight mode on or off.
    ///
    /// The highlight bar is put away on the way in, and stays away while the mode is on,
    /// because the mode is the other way of doing what the bar does.
    func setHighlighting(_ highlighting: Bool) {
        isHighlighting = highlighting
        if highlighting {
            hideHighlightBar()
        }
    }

    /// Shows the highlight bar beside whatever the click or drag left selected.
    ///
    /// A click that selected nothing but landed on a highlight shows the bar for that
    /// highlight instead. `point` is where the mouse was released, in the view's coordinates.
    ///
    /// In highlight mode no bar is shown, and a selection is asked to be highlighted instead.
    func mouseWentUp(at point: NSPoint) {
        guard !isHighlighting else {
            if view?.currentSelection != nil {
                highlightRequests += 1
            }
            return
        }
        followsSelection = true
        placeHighlightBar()
        guard selectionAnchor == nil,
              let view,
              let highlight = highlight(at: point),
              let anchor = anchor(of: highlight.lines, on: highlight.page, in: view)
        else { return }
        withAnimation(HighlightBar.animation) {
            selectedHighlight = highlight
            selectionAnchor = anchor
        }
    }

    /// The highlight a right click at `point` should remove, which is the one under it
    /// while highlight mode is on.
    ///
    /// Outside the mode there is none, and the click opens PDFKit's menu as usual.
    func highlightToRemove(at point: NSPoint) -> Highlight? {
        isHighlighting ? highlight(at: point) : nil
    }

    /// The highlight under `point`, which is in the view's coordinates.
    private func highlight(at point: NSPoint) -> Highlight? {
        guard let view, let page = view.page(for: point, nearest: false) else { return nil }
        return QuireDocument.highlight(at: view.convert(point, to: page), on: page)
    }

    /// Takes the highlight bar away, and stops it coming back until the next selection.
    func hideHighlightBar() {
        followsSelection = false
        guard selectionAnchor != nil else { return }
        withAnimation(HighlightBar.animation) {
            selectionAnchor = nil
            selectedHighlight = nil
        }
    }

    /// Applies `colour` to what the bar is showing for, and puts the bar away.
    ///
    /// A clicked highlight is recoloured. Selected text is highlighted, and the selection
    /// is then cleared, because it is drawn over the text in its own colour and would hide
    /// the highlight that was just made.
    func highlight(in colour: HighlightColour, of document: QuireDocument) {
        if let highlight = selectedHighlight {
            if highlight.isOnPage {
                document.recolourHighlight(highlight, to: colour)
            }
            hideHighlightBar()
            return
        }
        guard let view, let selection = view.currentSelection else { return }
        document.highlight(selection, in: colour)
        hideHighlightBar()
        view.clearSelection()
    }

    /// Removes the highlight the bar is showing for, and puts the bar away.
    func removeSelectedHighlight(from document: QuireDocument) {
        if let highlight = selectedHighlight, highlight.isOnPage {
            document.removeHighlight(highlight)
        }
        hideHighlightBar()
    }

    private func selectionDidChange() {
        guard followsSelection else { return }
        placeHighlightBar()
    }

    /// Hides the highlight bar when the document scrolls, since the text it sat beside has moved.
    ///
    /// Every scrolling view in the app posts the notification behind this, so it is only
    /// acted on when it comes from inside the PDF view.
    private func viewDidScroll(_ scrolled: NSClipView?) {
        guard let view, let scrolled, scrolled.isDescendant(of: view) else { return }
        hideHighlightBar()
    }

    /// Puts the highlight bar beside the selection, or removes it when nothing is selected.
    ///
    /// A bar showing for a clicked highlight is left alone while nothing is selected,
    /// and gives way to the selection once there is one.
    private func placeHighlightBar() {
        let anchor = currentSelectionAnchor
        guard anchor != nil || (selectionAnchor != nil && selectedHighlight == nil) else { return }
        withAnimation(HighlightBar.animation) {
            selectionAnchor = anchor
            selectedHighlight = nil
        }
    }

    /// Where the first and last lines of the selection are in the view.
    ///
    /// A selection can run over several lines and pages, and its overall bounds would put
    /// the bar beside the widest line rather than beside where the selection starts or ends.
    private var currentSelectionAnchor: SelectionAnchor? {
        guard let view,
              let lines = view.currentSelection?.selectionsByLine(),
              let first = lines.first,
              let last = lines.last,
              let firstPage = first.pages.first,
              let lastPage = last.pages.last,
              let top = anchor(of: [first.bounds(for: firstPage)], on: firstPage, in: view),
              let bottom = anchor(of: [last.bounds(for: lastPage)], on: lastPage, in: view)
        else { return nil }
        return SelectionAnchor(firstLine: top.firstLine, lastLine: bottom.lastLine)
    }

    /// Where the topmost and bottommost of some lines on a page are in the view.
    ///
    /// The lines are compared as they appear in the view rather than in the order given,
    /// because a rotated page turns the order around.
    ///
    /// The result is measured from the view's top-left corner. AppKit measures from the
    /// bottom-left unless a view says otherwise, and SwiftUI, which places the bar,
    /// measures from the top-left.
    private func anchor(of lines: [CGRect], on page: PDFPage, in view: PDFView) -> SelectionAnchor? {
        let rects = lines
            .map { view.convert($0, from: page) }
            .filter { !$0.isEmpty }
            .map { rect in
                view.isFlipped
                    ? rect
                    : CGRect(x: rect.minX, y: view.bounds.height - rect.maxY, width: rect.width, height: rect.height)
            }
        guard let first = rects.min(by: { $0.minY < $1.minY }),
              let last = rects.max(by: { $0.maxY < $1.maxY })
        else { return nil }
        return SelectionAnchor(firstLine: first, lastLine: last)
    }
}
