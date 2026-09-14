//
//  ImageExportRendererTests.swift
//  SakuttoSeatTests
//
//  v2.1 Phase 2（高画質スケールと PNG 一時ファイル）
//  v2.1 hotfix（人数上限の番号札が高画質でも書き出せること）
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

    func test_長辺が上限以内なら希望スケールを維持する() {
        let size = CGSize(width: 680, height: 400)
        XCTAssertEqual(
            ImageExportRenderer.clampedRenderScale(for: .highRes, contentSize: size, displayScale: 3),
            3
        )
        XCTAssertEqual(
            ImageExportRenderer.clampedRenderScale(for: .standard, contentSize: size, displayScale: 2),
            2
        )
    }

    func test_長辺が上限を超えるとスケールを落とす() {
        let size = CGSize(width: 680, height: 10_000)
        let scale = ImageExportRenderer.clampedRenderScale(
            for: .highRes,
            contentSize: size,
            displayScale: 3
        )

        XCTAssertLessThan(scale, 3)
        XCTAssertEqual(scale * size.height, ImageExportRenderer.maxPixelDimension, accuracy: 0.001)
    }

    func test_番号札の人数上限でも高画質PNGを書き出せる() throws {
        let seats = (1...FeatureLimit.maxAttendeeCount).map { index in
            NumberedSeat(id: UUID(), name: "参加者\(index)", number: index)
        }
        let viewData = SimpleShuffleViewDataBuilder.build(seats: seats)

        let image = try XCTUnwrap(
            ImageExportRenderer.renderSimpleShuffle(viewData: viewData, quality: .highRes)
        )
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertLessThanOrEqual(max(pixelWidth, pixelHeight), ImageExportRenderer.maxPixelDimension)
        XCTAssertEqual(
            image.size.width,
            SimpleShuffleSnapshotView.Layout.highRes.exportWidth(rowCount: FeatureLimit.maxAttendeeCount),
            accuracy: 1
        )

        let standard = try XCTUnwrap(
            ImageExportRenderer.renderSimpleShuffle(viewData: viewData, quality: .standard)
        )
        XCTAssertLessThanOrEqual(
            max(standard.size.width * standard.scale, standard.size.height * standard.scale),
            ImageExportRenderer.maxPixelDimension
        )

        let url = try XCTUnwrap(
            ImageExportRenderer.writeTemporaryPNG(image, fileName: "番号札_上限.png")
        )
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 8)
    }
}
