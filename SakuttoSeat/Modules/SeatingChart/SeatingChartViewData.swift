//
//  SeatingChartViewData.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 2（表示専用モデル）
//

import CoreGraphics
import Foundation

/// Presenter が生成し、View が消費する表示専用モデル。
/// Entity（`SeatingTable` / `SeatingMember`）はここに現れない。
struct SeatingChartViewData: Equatable {
    struct Row: Identifiable, Equatable {
        /// 先頭要素の安定 ID から生成（index を使わない）
        let id: String
        let items: [Item]
        let trailingFillerCount: Int
    }

    enum Item: Identifiable, Equatable {
        case table(TableViewData)
        case addButton

        var id: String {
            switch self {
            case .table(let table):
                return table.id.uuidString
            case .addButton:
                return "add-button"
            }
        }
    }

    let rows: [Row]
    let minGridWidth: CGFloat
    let isShuffleEnabled: Bool
    let isSaveEnabled: Bool
    let isShareEnabled: Bool
    /// 画像出力・共有テキスト用に Presenter が保持する会場列数の写し
    let globalColumnCount: Int

    static let empty = SeatingChartViewData(
        rows: [],
        minGridWidth: 0,
        isShuffleEnabled: false,
        isSaveEnabled: false,
        isShareEnabled: false,
        globalColumnCount: 2
    )
}

struct TableViewData: Identifiable, Equatable {
    let id: TableID
    let name: String
    let badge: LayoutDirection?
    let layoutLabel: String?
    let seats: [SeatViewData]
    let columnCount: Int
    let needsHorizontalScroll: Bool
    let accessibilitySummary: String
}

struct SeatViewData: Identifiable, Equatable {
    let id: String
    let memberID: MemberID?
    let displayName: String
    let isLocked: Bool

    var isEmpty: Bool { memberID == nil }
}

// MARK: - Entity → ViewData

enum SeatingChartViewDataBuilder {
    /// 旧 View 実装と同じ式: `(140 + 16) * columns + 32`
    private static let tableMinWidthWithSpacing: CGFloat = 140 + 16
    private static let gridPadding: CGFloat = 32

    static func build(tables: [SeatingTable], globalColumnCount: Int) -> SeatingChartViewData {
        let columnCount = max(1, globalColumnCount)
        let tableViewData = tables.map(makeTableViewData)
        let hasTables = !tables.isEmpty

        var items: [SeatingChartViewData.Item] = tableViewData.map { .table($0) }
        items.append(.addButton)

        let rows: [SeatingChartViewData.Row] = stride(from: 0, to: items.count, by: columnCount).map { start in
            let slice = Array(items[start..<min(start + columnCount, items.count)])
            let rowID = slice.first?.id ?? "row-\(start)"
            return SeatingChartViewData.Row(
                id: rowID,
                items: slice,
                trailingFillerCount: max(0, columnCount - slice.count)
            )
        }

        let minGridWidth = tableMinWidthWithSpacing * CGFloat(columnCount) + gridPadding

        return SeatingChartViewData(
            rows: rows,
            minGridWidth: minGridWidth,
            isShuffleEnabled: true,
            isSaveEnabled: hasTables,
            isShareEnabled: hasTables,
            globalColumnCount: columnCount
        )
    }

    static func makeTableViewData(from table: SeatingTable) -> TableViewData {
        let seats = makeSeats(from: table)
        let layoutLabel: String? = {
            guard table.layoutDirection != .none else { return nil }
            let trimmed = table.layoutText.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }()
        let occupiedNames = seats.compactMap { $0.isEmpty ? nil : $0.displayName }
        let accessibilitySummary = "\(table.name)、\(occupiedNames.count)人着席、定員\(table.capacity)"

        return TableViewData(
            id: table.id,
            name: table.name,
            badge: table.layoutDirection == .none ? nil : table.layoutDirection,
            layoutLabel: layoutLabel,
            seats: seats,
            columnCount: max(1, table.columnCount),
            needsHorizontalScroll: table.columnCount > 4,
            accessibilitySummary: accessibilitySummary
        )
    }

    static func makeSeats(from table: SeatingTable) -> [SeatViewData] {
        SeatSlot.slots(for: table).map { slot in
            SeatViewData(
                id: slot.id,
                memberID: slot.member?.id,
                displayName: slot.member?.name ?? "空席",
                isLocked: slot.member?.isLocked ?? false
            )
        }
    }

    /// スナップショット用に、追加ボタンを除いたテーブル行だけを返す
    static func tableOnlyRows(from viewData: SeatingChartViewData) -> [SeatingChartViewData.Row] {
        let tables = viewData.rows.flatMap { row in
            row.items.compactMap { item -> TableViewData? in
                if case .table(let table) = item { return table }
                return nil
            }
        }
        let columnCount = max(1, viewData.globalColumnCount)
        return stride(from: 0, to: tables.count, by: columnCount).map { start in
            let slice = Array(tables[start..<min(start + columnCount, tables.count)])
            let items = slice.map { SeatingChartViewData.Item.table($0) }
            return SeatingChartViewData.Row(
                id: items.first?.id ?? "snapshot-row-\(start)",
                items: items,
                trailingFillerCount: max(0, columnCount - slice.count)
            )
        }
    }
}
