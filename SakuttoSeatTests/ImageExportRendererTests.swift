//
//  ImageExportRendererTests.swift
//  SakuttoSeatTests
//
//  v2.1 Phase 2（高画質スケールと PNG 一時ファイル）
//

import UIKit
import XCTest
@testable import SakuttoSeat

@MainActor
final class ImageExportRendererTests: XCTestCase {

    func test_標準スケールはdisplayScale_高画質は最低3() {
        XCTAssertEqual(ImageExportRenderer.renderScale(for: .standard, displayScale: 2), 2)
        XCTAssertEqual(ImageExportRenderer.renderScale(for: .highRes, displayScale: 2), 3)
        XCTAssertEqual(ImageExportRenderer.renderScale(for: .standard, displayScale: 3), 3)
        XCTAssertEqual(ImageExportRenderer.renderScale(for: .highRes, displayScale: 3), 3)
        XCTAssertEqual(ImageExportRenderer.renderScale(for: .highRes, displayScale: 1), 3)
        XCTAssertEqual(ImageExportRenderer.highResScale, 3)
    }

    func test_writeTemporaryPNGはPNGシグネチャで書き出す() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let url = try XCTUnwrap(
            ImageExportRenderer.writeTemporaryPNG(image, fileName: "座席表_test.png")
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertEqual([UInt8](data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(url.lastPathComponent, "座席表_test.png")
    }

    func test_座席表レンダは標準も高画質も画像を返す() {
        let interactor = SeatingChartInteractor(attendees: [Attendee(name: "A"), Attendee(name: "B")])
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        let standard = ImageExportRenderer.renderSeatingChart(viewData: viewData, quality: .standard)
        let highRes = ImageExportRenderer.renderSeatingChart(viewData: viewData, quality: .highRes)

        XCTAssertNotNil(standard)
        XCTAssertNotNil(highRes)
        XCTAssertGreaterThan(standard?.size.width ?? 0, 0)
        XCTAssertGreaterThan(highRes?.size.width ?? 0, 0)
    }

    func test_番号札レンダは高画質の方が幅が広い() {
        let viewData = SimpleShuffleViewDataBuilder.build(
            seats: [NumberedSeat(id: UUID(), name: "太郎", number: 1)]
        )

        let standard = ImageExportRenderer.renderSimpleShuffle(viewData: viewData, quality: .standard)
        let highRes = ImageExportRenderer.renderSimpleShuffle(viewData: viewData, quality: .highRes)

        XCTAssertNotNil(standard)
        XCTAssertNotNil(highRes)
        XCTAssertEqual(standard?.size.width, SimpleShuffleSnapshotView.exportWidth)
        XCTAssertEqual(highRes?.size.width, SimpleShuffleSnapshotView.highResExportWidth)
        XCTAssertGreaterThan(highRes?.size.width ?? 0, standard?.size.width ?? 0)
    }
}
