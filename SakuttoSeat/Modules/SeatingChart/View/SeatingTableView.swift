//
//  SeatingTableView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//

import SwiftUI

/// 個別のテーブル表示用コンポーネント（メイン画面用）
///
/// Entity ではなく `TableViewData` を受け取る。
/// Phase 6 で `SnapshotSeatingTableView` と統合して `SeatingTableCard` にする予定。
struct SeatingTableView: View {
    let table: TableViewData
    let onEditTarget: () -> Void
    let onTapSeat: (MemberID) -> Void

    @ViewBuilder
    private func badgeTop() -> some View {
        if table.badge == .top {
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
        if table.badge == .bottom {
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
        if table.badge == .left {
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
        if table.badge == .right {
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

            let minSeatWidth: CGFloat = 72
            let columnCount = table.columnCount
            let desiredWidth = CGFloat(columnCount) * minSeatWidth

            Group {
                if table.needsHorizontalScroll {
                    ScrollView(.horizontal, showsIndicators: true) {
                        seatGrid(seats: table.seats, columnCount: columnCount, minCellWidth: minSeatWidth)
                            .frame(minWidth: desiredWidth)
                    }
                } else {
                    seatGrid(seats: table.seats, columnCount: columnCount, minCellWidth: 0)
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: table.seats)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            onEditTarget()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(table.accessibilitySummary)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        .overlay(badgeTop(), alignment: .top)
        .overlay(badgeBottom(), alignment: .bottom)
        .overlay(badgeLeft(), alignment: .leading)
        .overlay(badgeRight(), alignment: .trailing)
    }

    @ViewBuilder
    private func seatGrid(seats: [SeatViewData], columnCount: Int, minCellWidth: CGFloat) -> some View {
        SeatGridLayout(
            columnCount: columnCount,
            horizontalSpacing: 8,
            verticalSpacing: 12,
            minCellWidth: minCellWidth
        ) {
            ForEach(seats) { seat in
                if let memberID = seat.memberID {
                    Button {
                        onTapSeat(memberID)
                    } label: {
                        SeatView(seat: seat)
                    }
                    .buttonStyle(.plain)
                } else {
                    SeatView(seat: seat)
                }
            }
        }
    }
}
