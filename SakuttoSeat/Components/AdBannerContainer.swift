//
//  AdBannerContainer.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 6（画面側の 320×50 固定を廃止し、幅に追従する）
//

import SwiftUI

/// 親の幅に合わせたアダプティブバナー。VoiceOver では広告を飛ばして操作できるように隠す。
struct AdBannerContainer: View {
    @State private var bannerWidth: CGFloat = 0

    var body: some View {
        Group {
            if bannerWidth > 0 {
                AdBannerView(width: bannerWidth)
                    .frame(height: AdBannerMetrics.size(forWidth: bannerWidth).height)
            } else {
                Color.clear
                    .frame(height: AppSpacing.bannerFallbackHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: BannerWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(BannerWidthPreferenceKey.self) { bannerWidth = $0 }
        .accessibilityHidden(true)
    }
}

private struct BannerWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
