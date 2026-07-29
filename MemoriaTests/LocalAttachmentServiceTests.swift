import XCTest
@testable import Memoria

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Regression coverage for attachment files outliving the trades that owned them.
/// SwiftData cascades away the rows; the JPEGs on disk are ours to clean up.
@MainActor
final class LocalAttachmentServiceTests: XCTestCase {

    private let service = LocalAttachmentService.shared

    // MARK: - Helpers

    /// A tiny valid image the service can decode and re-encode to JPEG.
    private func sampleImageData() throws -> Data {
        #if os(macOS)
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 4, height: 4))
        image.unlockFocus()
        return try XCTUnwrap(image.tiffRepresentation)
        #else
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.jpegData(withCompressionQuality: 1) { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        #endif
    }

    private func makeTradeWithAttachment(_ ticker: String = "AAPL") throws -> Trade {
        let attachmentId = try XCTUnwrap(service.saveImage(from: sampleImageData()))
        let trade = Trade(ticker: ticker)
        trade.attachmentId = attachmentId
        return trade
    }

    // MARK: - Tests

    /// Swipe-to-delete on a single trade (TradesListView).
    func testDeleteImages_purgesFileForDeletedTrade() throws {
        let trade = try makeTradeWithAttachment()
        let id = try XCTUnwrap(trade.attachmentId)

        XCTAssertNotNil(service.loadImageData(id: id), "fixture should exist before deletion")

        service.deleteImages(for: [trade])

        XCTAssertNil(service.loadImageData(id: id), "attachment leaked after its trade was deleted")
    }

    /// Portfolio deletion and Reset Portfolio, where many trades die at once.
    func testDeleteImages_purgesEveryTradesFile() throws {
        let trades = try (0..<3).map { try makeTradeWithAttachment("T\($0)") }
        let ids = try trades.map { try XCTUnwrap($0.attachmentId) }

        service.deleteImages(for: trades)

        for id in ids {
            XCTAssertNil(service.loadImageData(id: id), "attachment \(id) leaked")
        }
    }

    /// Trades without a screenshot must not disrupt the sweep.
    func testDeleteImages_skipsTradesWithoutAttachment() throws {
        let bare = Trade(ticker: "MSFT")
        let illustrated = try makeTradeWithAttachment()
        let id = try XCTUnwrap(illustrated.attachmentId)

        service.deleteImages(for: [bare, illustrated])

        XCTAssertNil(service.loadImageData(id: id))
    }
}
