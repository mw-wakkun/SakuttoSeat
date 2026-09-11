//
//  AdBannerContainer.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 6（画面側の 320×50 固定を廃止し、幅に追従する）
//  番号札のように inset 内がバナーだけの画面では、子の ideal 幅が 0 になり
//  PreferenceKey では計測できない。containerRelativeFrame で親幅を確定する。
//

import SwiftUI

/// 親の幅に合わせたアダプティブバナー。VoiceOver では広告を飛ばして操作できるように隠す。
struct AdBannerContainer: View {
    @State private var bannerWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if bannerWidth > 0 {
                AdBannerView(width: bannerWidth)
                    .frame(width: bannerWidth, height: bannerHeight)
            }
        }
        .frame(height: bannerHeight)
        .containerRelativeFrame(.horizontal)
        .clipped()
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
            updateWidth(newWidth)
        }
        .accessibilityHidden(true)
    }

    private var bannerHeight: CGFloat {
        bannerWidth > 0
            ? AdBannerMetrics.size(forWidth: bannerWidth).height
            : AppSpacing.bannerFallbackHeight
    }

    private func updateWidth(_ width: CGFloat) {
        guard width > 0, abs(width - bannerWidth) >= 0.5 else { return }
        bannerWidth = width
    }
}
