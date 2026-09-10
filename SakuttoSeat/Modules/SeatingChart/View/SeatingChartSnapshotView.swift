//
//  SeatingChartSnapshotView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//

import SwiftUI

// MARK: - 画像出力用スナップショット

/// 画像出力専用の座席表全体ビュー
///
/// Phase 5 で出力サイズの実測化、Phase 6 で `SeatingTableCard` への統合を行う予定。
struct SeatingChartSnapshotView: View {
    let viewData: SeatingChartViewData

    var body: some View {
        let rows = SeatingChartViewDataBuilder.tableOnlyRows(from: viewData)
        VStack(spacing: 16) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row.items) { item in
                        if case .table(let table) = item {
                            SnapshotSeatingTableView(table: table)
                                .frame(width: 140)
                        }
                    }
                    ForEach(0..<row.trailingFillerCount, id: \.self) { _ in
                        Color.clear
                            .frame(width: 140)
                    }
                }
            }
        }
        .padding(32)
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
                                SeatView(seat: seats[index])
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
