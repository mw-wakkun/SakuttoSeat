//
//  SimpleShuffleSnapshotView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（共有画像用。行 UI は NumberedPersonRow）
//

import SwiftUI

struct SimpleShuffleSnapshotView: View {
    let attendees: [String]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("【サクッと席決め】")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                Text("シャッフル結果（番号札）")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(Array(attendees.enumerated()), id: \.offset) { index, name in
                    NumberedPersonRow(
                        number: index + 1,
                        name: name,
                        accessory: String(localized: "番席"),
                        tint: .blue,
                        rowVerticalPadding: 0
                    )
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
    }
}
