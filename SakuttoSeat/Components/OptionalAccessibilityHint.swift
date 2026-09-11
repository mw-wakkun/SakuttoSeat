//
//  OptionalAccessibilityHint.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 6（閉じる / 編集 / 空状態 / CTA で共有。nil と空文字は Hint を付けない）
//

import SwiftUI

struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
