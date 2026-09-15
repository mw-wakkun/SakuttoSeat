//
//  EmptyStateView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧とテンプレート一覧で共有できる空状態）
//  refactor_favorite.md Phase 6（装飾アイコンは VoiceOver から隠す。Hint は呼び出し側）
//  v2.1 UI/UX（装飾アイコンも Dynamic Type）
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var imageFont: Font = .largeTitle
    var imageColor: Color = .gray.opacity(0.5)
    var spacing: CGFloat = 16
    var accessibilityHint: String? = nil

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(imageFont)
                .foregroundColor(imageColor)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
    }
}
