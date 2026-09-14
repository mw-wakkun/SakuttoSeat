//
//  PresentToolbarButton.swift
//  SakuttoSeat
//
//  v2.1 UI/UX（ナビの発表。この幅ではアイコンか文言か片方。発見性は「発表」が担う）
//

import SwiftUI

/// 座席表・番号札の leading ツールバー。文言のみ（システムが戻ると同じカプセルに包む）。
struct PresentToolbarButton: View {
    let isEnabled: Bool
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(PresentationCopy.presentToolbarTitle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .disabled(!isEnabled)
        .accessibilityLabel(PresentationCopy.presentAccessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}
