//
//  EmptyStateView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧とテンプレート一覧で共有できる空状態）
//  refactor_favorite.md Phase 6（装飾アイコンは VoiceOver から隠す。Hint は呼び出し側）
//  v2.1 UI/UX（装飾アイコンは ScaledMetric。largeTitle にするとヒーロー空状態が小さすぎる）
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var imagePointSize: CGFloat = AppSpacing.emptyStateIconSize
    var imageColor: Color = .gray.opacity(0.5)
    var spacing: CGFloat = 16
    var accessibilityHint: String? = nil

    var body: some View {
        VStack(spacing: spacing) {
            EmptyStateIcon(
                systemImage: systemImage,
                pointSize: imagePointSize,
                color: imageColor
            )
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
    }
}

/// `@ScaledMetric` は呼び出し側の pt を初期値にするため子 View に閉じる。
private struct EmptyStateIcon: View {
    let systemImage: String
    let color: Color
    /// 宣言側に初期値が必要。init で呼び出し側の pt に差し替える。
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = AppSpacing.emptyStateIconSize

    init(systemImage: String, pointSize: CGFloat, color: Color) {
        self.systemImage = systemImage
        self.color = color
        _size = ScaledMetric(wrappedValue: pointSize, relativeTo: .largeTitle)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size))
            .foregroundColor(color)
            .accessibilityHidden(true)
    }
}
