//
//  SeatingTableView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//  v2.1 Phase 3（発表は読み取り専用 chrome）
//  v2.1 UI/UX（卓の鉛筆、席の A11y。発表では出さない）
//

import SwiftUI

/// 個別のテーブル表示用コンポーネント（メイン画面用）
///
/// Entity ではなく `TableViewData` を受け取る。
/// Phase 6 で `SnapshotSeatingTableView` と統合して `SeatingTableCard` にする予定。
struct SeatingTableView: View {
    let table: TableViewData
    var chrome: SeatingChrome = .interactive
    var onEditTarget: () -> Void = {}
    var onTapSeat: (MemberID) -> Void = { _ in }

    private var isInteractive: Bool { chrome == .interactive }

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
                HStack(spacing: 4) {
                    Text(table.name)
                        .font(chrome == .presentation ? .headline : .caption)
                        .bold()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isInteractive {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(table.accessibilitySummary)
                .modifier(
                    OptionalAccessibilityHint(
                        hint: isInteractive ? SeatingChartCopy.editTableHint : nil
                    )
                )

                if let layoutLabel = table.layoutLabel {
                    Text(layoutLabel)
                        .font(.system(size: chrome == .presentation ? 13 : 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            let minSeatWidth: CGFloat = chrome == .presentation ? 96 : 72
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
            .fixedSize(horizontal: false, vertical: true)
            .animation(
                isInteractive ? .spring(response: 0.6, dampingFraction: 0.8) : nil,
                value: table.seats
            )
        }
        .padding(chrome == .presentation ? 20 : 15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isInteractive else { return }
            onEditTarget()
        }
        .accessibilityElement(children: .contain)
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
                if isInteractive, let memberID = seat.memberID {
                    Button {
                        onTapSeat(memberID)
                    } label: {
                        SeatView(seat: seat, chrome: chrome)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(seat.displayName)
                    .accessibilityValue(seat.isLocked ? SeatingChartCopy.lockedValue : "")
                    .modifier(
                        OptionalAccessibilityHint(
                            hint: seat.isLocked
                                ? SeatingChartCopy.unlockSeatHint
                                : SeatingChartCopy.lockSeatHint
                        )
                    )
                } else {
                    SeatView(seat: seat, chrome: chrome)
                        .accessibilityLabel(seat.displayName)
                }
            }
        }
    }
}
