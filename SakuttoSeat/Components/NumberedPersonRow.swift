//
//  NumberedPersonRow.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（番号札の行 UI を 1 実装に統合）
//

import SwiftUI

struct NumberedPersonRow: View {
    let number: Int
    let name: String
    var accessory: String? = nil
    var tint: Color = .sakuttoBlueStart
    var circleSize: CGFloat = 32
    var rowVerticalPadding: CGFloat = 4

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.1))
                    .frame(width: circleSize, height: circleSize)
                Text("\(number)")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundColor(tint)
            }

            Text(name)
                .font(.body)
                .padding(.leading, 8)

            Spacer()

            if let accessory {
                Text(accessory)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, rowVerticalPadding)
    }
}
