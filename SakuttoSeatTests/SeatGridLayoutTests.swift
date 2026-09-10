//
//  SeatGridLayoutTests.swift
//  SakuttoSeatTests
//

import XCTest
import SwiftUI
@testable import SakuttoSeat

/// `SeatGridLayout` のレイアウト計算を実レンダリングで検証する。
///
/// この Layout は `Grid` / `GridRow` を置き換えるものなので、
/// 行数・列幅・全体の高さが破綻していないことを寸法で担保する。
@MainActor
final class SeatGridLayoutTests: XCTestCase {

    private func makeSlots(count: Int) -> [SeatSlot] {
        (0..<count).map { index in
            SeatSlot(id: "seat-\(index)", member: SeatingMember(id: UUID(), name: "参加者\(index)"))
        }
    }

    /// 指定条件でレイアウトを実際に描画し、確定したサイズを返す
    private func renderedSize(
        slotCount: Int,
        columnCount: Int,
        proposedWidth: CGFloat?,
        minCellWidth: CGFloat = 0
    ) -> CGSize? {
        let slots = makeSlots(count: slotCount)
        let content = SeatGridLayout(columnCount: columnCount, minCellWidth: minCellWidth) {
            ForEach(slots) { slot in
                SeatView(seat: SeatViewData(
                    id: slot.id,
                    memberID: slot.member?.id,
                    displayName: slot.member?.name ?? "空席",
                    isLocked: slot.member?.isLocked ?? false
                ))
            }
        }

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
        return renderer.uiImage?.size
    }

    func test_列数が少ないほど行数が増えて高さが伸びる() throws {
        let twoColumns = try XCTUnwrap(renderedSize(slotCount: 4, columnCount: 2, proposedWidth: 200))
        let fourColumns = try XCTUnwrap(renderedSize(slotCount: 4, columnCount: 4, proposedWidth: 200))

        // 同じ 4 席でも 2 列なら 2 行、4 列なら 1 行になる
        XCTAssertGreaterThan(twoColumns.height, fourColumns.height)
    }

    func test_提案された幅にそって列が均等割りされる() throws {
        let size = try XCTUnwrap(renderedSize(slotCount: 4, columnCount: 2, proposedWidth: 200))

        // 幅の提案どおりに収まる（列幅 + 余白の合計が提案幅と一致する）
        XCTAssertEqual(size.width, 200, accuracy: 1.0)
    }

    func test_行が増えると高さが単調に増加する() throws {
        let oneRow = try XCTUnwrap(renderedSize(slotCount: 2, columnCount: 2, proposedWidth: 200))
        let twoRows = try XCTUnwrap(renderedSize(slotCount: 4, columnCount: 2, proposedWidth: 200))
        let threeRows = try XCTUnwrap(renderedSize(slotCount: 6, columnCount: 2, proposedWidth: 200))

        XCTAssertGreaterThan(twoRows.height, oneRow.height)
        XCTAssertGreaterThan(threeRows.height, twoRows.height)
    }

    func test_最小幅を指定すると座席が潰れずに横へ広がる() throws {
        // 多列レイアウト（横スクロール）で使う経路。狭い幅を提案しても最小幅が確保される
        let size = try XCTUnwrap(
            renderedSize(slotCount: 10, columnCount: 10, proposedWidth: 100, minCellWidth: 72)
        )

        // 10 列 × 最小幅 72 + 余白 9 × 8 = 792 以上
        XCTAssertGreaterThanOrEqual(size.width, 72 * 10 + 8 * 9)
    }

    func test_最終行が埋まっていなくても列数ぶんの幅を保つ() throws {
        let full = try XCTUnwrap(renderedSize(slotCount: 4, columnCount: 2, proposedWidth: 200))
        let partial = try XCTUnwrap(renderedSize(slotCount: 3, columnCount: 2, proposedWidth: 200))

        // テーブルごとの横幅を揃えるため、端数の行があっても幅は変わらない
        XCTAssertEqual(full.width, partial.width, accuracy: 1.0)
    }

    func test_座席が空でも描画が破綻しない() {
        let content = SeatGridLayout(columnCount: 2) {
            ForEach([SeatSlot]()) { slot in
                SeatView(seat: SeatViewData(
                    id: slot.id,
                    memberID: slot.member?.id,
                    displayName: slot.member?.name ?? "空席",
                    isLocked: slot.member?.isLocked ?? false
                ))
            }
        }
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 200, height: nil)

        // サイズ 0 のビューは uiImage が nil になるためクラッシュしないことのみ確認する
        _ = renderer.uiImage
    }
}
