//
//  SeatingChartSnapshotView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）
//

import SwiftUI

// MARK: - 画像出力用スナップショット

/// 画像出力専用の座席表全体ビュー
///
/// Phase 5 で出力サイズの実測化、Phase 6 で `SeatingTableCard` への統合を行う予定。
struct SeatingChartSnapshotView: View {
    let tables: [SeatingTable]
    let globalColumnCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(tableRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row) { table in
                        SnapshotSeatingTableView(table: table)
                            .frame(width: 140) // テーブル幅を固定して大きさを揃える
                    }
                    // 行の末尾が列数に満たない場合、グリッド構造を保つため空ビューで埋める
                    let emptyCount = globalColumnCount - row.count
                    if emptyCount > 0 {
                        ForEach(0..<emptyCount, id: \.self) { _ in
                            Color.clear
                                .frame(width: 140)
                        }
                    }
                }
            }
        }
        .padding(32)
    }
    
    private var tableRows: [[SeatingTable]] {
        stride(from: 0, to: tables.count, by: globalColumnCount).map { start in
            Array(tables[start..<min(start + globalColumnCount, tables.count)])
        }
    }
}

// MARK: - 画像出力専用のテーブル表示コンポーネント

/// 画像出力用のテーブル表示
///
/// LazyVGrid は画面外を描画しないため見切れる。こちらは VStack / HStack で全て即時描画する。
struct SnapshotSeatingTableView: View {
    let table: SeatingTable
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                
                if table.layoutDirection != .none && !table.layoutText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(table.layoutText)
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
            
            // 全ての席（空席含む）の配列を作成
            let assignedOptional: [SeatingMember?] = table.assignedMembers.map { Optional($0) }
            let paddingCount = max(0, table.capacity - table.assignedMembers.count)
            let padding: [SeatingMember?] = Array(repeating: nil, count: paddingCount)
            let allSeats = assignedOptional + padding
            let colCount = max(1, table.columnCount)
            let rowCount = (allSeats.count + colCount - 1) / colCount
            
            VStack(spacing: 12) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 12) {
                        ForEach(0..<colCount, id: \.self) { colIndex in
                            let index = rowIndex * colCount + colIndex
                            if index < allSeats.count {
                                SeatView(member: allSeats[index])
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
        if table.layoutDirection == .top {
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
        if table.layoutDirection == .bottom {
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
        if table.layoutDirection == .left {
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
        if table.layoutDirection == .right {
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
