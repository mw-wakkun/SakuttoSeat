//
//  SeatingChartSnapshotView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//  v2.1 Phase 2（高画質はタイト余白・フィラー省略。画面用 View には広げない）
//  v2.1 UI/UX（席名は snapshot chrome で固定 pt）
//

import SwiftUI

// MARK: - 画像出力用スナップショット

/// 画像出力専用の座席表全体ビュー
///
/// Phase 6 で `SeatingTableCard` への統合を行う予定。
struct SeatingChartSnapshotView: View {
    /// 標準 / 高画質のレイアウト差。画面の `SeatingChartView` には使わない。
    nonisolated enum Layout: Equatable, Sendable {
        case standard
        case highRes

        var contentPadding: CGFloat {
            switch self {
            case .standard:
                return SeatingChartSnapshotView.contentPadding
            case .highRes:
                return SeatingChartSnapshotView.highResContentPadding
            }
        }

        var hidesFillers: Bool {
            self == .highRes
        }
    }

    /// 出力幅の算出に使うレイアウト定数（`ImageExportRenderer` と共有する唯一の定義）
    nonisolated static let tableWidth: CGFloat = 140
    nonisolated static let tableSpacing: CGFloat = 16
    nonisolated static let contentPadding: CGFloat = 32
    nonisolated static let highResContentPadding: CGFloat = 8

    /// 会場列数ぶんのテーブルが収まる幅。高さは `ImageRenderer` に実測させる。
    static func intrinsicWidth(columnCount: Int, layout: Layout = .standard) -> CGFloat {
        let columns = CGFloat(max(1, columnCount))
        return tableWidth * columns + tableSpacing * (columns - 1) + layout.contentPadding * 2
    }

    /// 高画質は空のフィラーを切るので、実在テーブルが占める列数で幅を決める。
    static func exportColumnCount(for viewData: SeatingChartViewData, layout: Layout = .standard) -> Int {
        let venueColumns = max(1, viewData.globalColumnCount)
        guard layout.hidesFillers else { return venueColumns }

        let tableCount = viewData.rows.flatMap(\.items).reduce(into: 0) { count, item in
            if case .table = item { count += 1 }
        }
        return max(1, min(tableCount, venueColumns))
    }

    let viewData: SeatingChartViewData
    var layout: Layout = .standard

    var body: some View {
        let rows = SeatingChartViewDataBuilder.tableOnlyRows(
            from: viewData,
            hidesFillers: layout.hidesFillers
        )
        VStack(spacing: Self.tableSpacing) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: Self.tableSpacing) {
                    ForEach(row.items) { item in
                        if case .table(let table) = item {
                            SnapshotSeatingTableView(table: table)
                                .frame(width: Self.tableWidth)
                        }
                    }
                    ForEach(0..<row.trailingFillerCount, id: \.self) { _ in
                        Color.clear
                            .frame(width: Self.tableWidth)
                    }
                }
            }
        }
        .padding(layout.contentPadding)
    }
}

// MARK: - 画像出力専用のテーブル表示コンポーネント

struct SnapshotSeatingTableView: View {
    let table: TableViewData

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                if let layoutLabel = table.layoutLabel {
                    Text(layoutLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            let colCount = table.columnCount
            let seats = table.seats
            let rowCount = (seats.count + colCount - 1) / colCount

            VStack(spacing: 12) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 12) {
                        ForEach(0..<colCount, id: \.self) { colIndex in
                            let index = rowIndex * colCount + colIndex
                            if index < seats.count {
                                SeatView(seat: seats[index], chrome: .snapshot)
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        .overlay(badgeTopSmall(), alignment: .top)
        .overlay(badgeBottomSmall(), alignment: .bottom)
        .overlay(badgeLeftSmall(), alignment: .leading)
        .overlay(badgeRightSmall(), alignment: .trailing)
    }

    @ViewBuilder
    private func badgeTopSmall() -> some View {
        if table.badge == .top {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.up")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(y: -4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgeBottomSmall() -> some View {
        if table.badge == .bottom {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.down")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(y: 4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgeLeftSmall() -> some View {
        if table.badge == .left {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.left")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(x: -4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgeRightSmall() -> some View {
        if table.badge == .right {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.right")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(x: 4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
}
