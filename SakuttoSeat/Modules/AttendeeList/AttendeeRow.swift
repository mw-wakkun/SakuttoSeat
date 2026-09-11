//
//  AttendeeRow.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 1（AttendeeListView からのファイル分離）
//

import SwiftUI

struct AttendeeRow: View {
    let number: Int
    let name: String

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.sakuttoBlueStart.opacity(0.1))
                    .frame(width: 35, height: 35)

                Text("\(number)")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundColor(.sakuttoBlueStart)
            }

            Text(name)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
