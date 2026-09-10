//
//  SeatingTableView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）
//

import SwiftUI

/// 個別のテーブル表示用コンポーネント（メイン画面用）
///
/// Phase 2 で Entity（`SeatingTable`）ではなく表示専用モデルを受け取るようにし、
/// Phase 6 で `SnapshotSeatingTableView` と統合して `SeatingTableCard` にする予定。
struct SeatingTableView: View {
    let table: SeatingTable
    @ObservedObject var presenter: SeatingChartPresenter
    let onEditTarget: () -> Void
    
    // バッジ描画のヘルパー（個別に切り出すことで型推論負荷を下げつつ、確実に表示させる）
    @ViewBuilder
    private func badgeTop() -> some View {
        if table.layoutDirection == .top {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(y: -6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeBottom() -> some View {
        if table.layoutDirection == .bottom {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(y: 6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeLeft() -> some View {
        if table.layoutDirection == .left {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.left")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(x: -6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeRight() -> some View {
        if table.layoutDirection == .right {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(x: 6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
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
            
            // 座席グリッドは LazyVGrid だと親の高さ計算が不安定になるため、
            // 即時レイアウトの SeatGridLayout を使う
            let minSeatWidth: CGFloat = 72
            let columnCount = max(1, table.columnCount)
            let desiredWidth = CGFloat(columnCount) * minSeatWidth
            let slots = SeatSlot.slots(for: table)
            
            Group {
                if columnCount <= 4 {
                    // カード幅に合わせて均等割りするため最小幅は指定しない
                    seatGrid(slots: slots, columnCount: columnCount, minCellWidth: 0)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        seatGrid(slots: slots, columnCount: columnCount, minCellWidth: minSeatWidth)
                            .frame(minWidth: desiredWidth)
                    }
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: table.assignedMembers)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            onEditTarget()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        // レイアウト方向バッジ（枠の辺の中央に表示）
        .overlay(badgeTop(), alignment: .top)
        .overlay(badgeBottom(), alignment: .bottom)
        .overlay(badgeLeft(), alignment: .leading)
        .overlay(badgeRight(), alignment: .trailing)
    }
    
    @ViewBuilder
    private func seatGrid(slots: [SeatSlot], columnCount: Int, minCellWidth: CGFloat) -> some View {
        SeatGridLayout(
            columnCount: columnCount,
            horizontalSpacing: 8,
            verticalSpacing: 12,
            minCellWidth: minCellWidth
        ) {
            // シャッフル時に SwiftUI が座席の「移動」を検出できるよう、
            // 行ごとに入れ子にせず単一の ForEach で全座席を並べる。
            // ここを行・列のインデックスで入れ子にするとアニメーションが失われる。
            ForEach(slots) { slot in
                if let member = slot.member {
                    Button {
                        presenter.toggleLock(tableId: table.id, memberId: member.id)
                    } label: {
                        SeatView(member: member)
                    }
                    .buttonStyle(.plain)
                } else {
                    SeatView(member: nil)
                }
            }
        }
    }
}
