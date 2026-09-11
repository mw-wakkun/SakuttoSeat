//
//  AppButtonStyles.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 6（AnyView 廃止。Primary / Secondary CTA）
//

import SwiftUI

struct SakuttoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.ctaButtonHeight)
            .background(Color.sakuttoGradient)
            .cornerRadius(AppSpacing.ctaCornerRadius)
            .shadow(
                color: Color.sakuttoBlueStart.opacity(0.3),
                radius: AppSpacing.ctaShadowRadius,
                x: 0,
                y: AppSpacing.ctaShadowY
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SakuttoSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.ctaButtonHeight)
            .background(tint.opacity(0.1))
            .cornerRadius(AppSpacing.ctaCornerRadius)
            .shadow(
                color: tint.opacity(0.3),
                radius: AppSpacing.ctaShadowRadius,
                x: 0,
                y: AppSpacing.ctaShadowY
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
