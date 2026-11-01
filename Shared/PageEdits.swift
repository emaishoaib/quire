#if os(macOS)
import AppKit
#else
import UIKit
#endif
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PageState {
    let page: PDFPage
    let rotation: Int
}

extension PDFModel {
    static let editAnimation = Animation.spring(duration: 0.3, bounce: 0.15)

    var pageCount: Int { pages.count }

    var pageStates: [PageState] {
        (0..<pdf.pageCount).compactMap { pdf.page(at: $0) }.map {
            PageState(page: $0, rotation: $0.rotation)
        }
    }

    func applyPages(_ newState: [PageState], actionName: String) {
        let oldState = pageStates

        for index in stride(from: pdf.pageCount - 1, through: 0, by: -1) {
            pdf.removePage(at: index)
        }
        for (index, item) in newState.enumerated() {
            item.page.rotation = item.rotation
            pdf.insert(item.page, at: index)
        }
        withAnimation(Self.editAnimation) {
            pages = newState.map(\.page)
            revision += 1
        }

        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.applyPages(oldState, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }

    func movePages(_ indices: IndexSet, to destination: Int) {
        var newState = pageStates
        newState.move(fromOffsets: indices, toOffset: destination)
        applyPages(newState, actionName: "Move Pages")
    }

    func rotatePages(_ indices: IndexSet, by degrees: Int) {
        let newState = pageStates.enumerated().map { index, item in
            guard indices.contains(index) else { return item }
            let rotation = ((item.rotation + degrees) % 360 + 360) % 360
            return PageState(page: item.page, rotation: rotation)
        }
        applyPages(newState, actionName: "Rotate Pages")
    }

    func deletePages(_ indices: IndexSet) {
        guard indices.count < pageCount else { return }
        let newState = pageStates.enumerated()
            .filter { !indices.contains($0.offset) }
            .map(\.element)
        applyPages(newState, actionName: "Delete Pages")
    }

    @discardableResult
    func insertPages(from url: URL, at index: Int) throws -> Int {
        let inserted = try Self.isImage(url)
            ? [Self.imagePage(of: url)]
            : Self.copiedPages(of: url)
        guard !inserted.isEmpty else { return 0 }

        var newState = pageStates
        newState.insert(contentsOf: inserted, at: min(index, newState.count))
        applyPages(newState, actionName: "Insert Pages")
        return inserted.count
    }

    private static func copiedPages(of url: URL) throws -> [PageState] {
        guard let other = PDFDocument(url: url), !other.isLocked else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (0..<other.pageCount).compactMap { index -> PageState? in
            guard let copy = other.page(at: index)?.copy() as? PDFPage else { return nil }
            return PageState(page: copy, rotation: copy.rotation)
        }
    }

    static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    private static func imagePage(of url: URL) throws -> PageState {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let pixels = CGImageSourceCreateImageAtIndex(source, 0, nil),
              pixels.width > 0, pixels.height > 0
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let rotation = switch orientation {
        case 3, 4: 180
        case 5, 6: 90
        case 7, 8: 270
        default: 0
        }

        let size = CGSize(
            width: CGFloat(pixels.width) * 72 / dotsPerInch(properties, kCGImagePropertyDPIWidth),
            height: CGFloat(pixels.height) * 72 / dotsPerInch(properties, kCGImagePropertyDPIHeight)
        )

        #if os(macOS)
        let image = NSImage(cgImage: pixels, size: size)
        #else
        let image = UIImage(cgImage: pixels, scale: CGFloat(pixels.width) / size.width, orientation: .up)
        #endif
        guard let page = PDFPage(image: image) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return PageState(page: page, rotation: rotation)
    }

    private static func dotsPerInch(_ properties: [CFString: Any]?, _ key: CFString) -> CGFloat {
        guard let stated = properties?[key] as? Double, stated > 0 else { return 72 }
        return stated
    }
}
