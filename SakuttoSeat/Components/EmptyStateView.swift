//
//  EmptyStateView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧とテンプレート一覧で共有できる空状態）
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var imageFont: Font = .system(size: 50)
    var imageColor: Color = .gray.opacity(0.5)
    var spacing: CGFloat = 16

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(imageFont)
                .foregroundColor(imageColor)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
