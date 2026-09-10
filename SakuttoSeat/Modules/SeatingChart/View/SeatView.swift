//
//  SeatView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//

import SwiftUI

/// 1つ1つの「座席」
///
/// Phase 6 で `SeatCell` へ改名予定。Entity ではなく `SeatViewData` を受け取る。
struct SeatView: View {
    let seat: SeatViewData

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: seat.isLocked ? "person.circle.fill" : "person.circle")
                    .font(.system(size: 24))
                    .foregroundColor(seat.isEmpty ? .gray.opacity(0.3) : (seat.isLocked ? .red : .blue))

                if seat.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
            }

            Text(seat.displayName)
                .font(.system(size: 11, weight: seat.isLocked ? .bold : .medium))
                .foregroundColor(seat.isEmpty ? .gray.opacity(0.5) : (seat.isLocked ? .red : .primary))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            seat.isLocked
            ? Color.red.opacity(0.1)
            : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(6)
    }
}
