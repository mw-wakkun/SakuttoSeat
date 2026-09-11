//
//  AdBannerView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/16.
//  refactor_AttendeeList.md Phase 6（アダプティブサイズ。Coordinator で同じサイズなら再 load しない）
//

import GoogleMobileAds
import SwiftUI

/// バナー広告のサイズ計算。View は `AdBannerContainer` 経由で使う。
enum AdBannerMetrics {
    static func anchoredAdaptiveAdSize(width: CGFloat) -> AdSize {
        largeAnchoredAdaptiveBanner(width: max(width, 1))
    }

    static func size(forWidth width: CGFloat) -> CGSize {
        anchoredAdaptiveAdSize(width: width).size
    }
}

struct AdBannerView: UIViewRepresentable {
    var width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        context.coordinator.makeBanner(adSize: AdBannerMetrics.anchoredAdaptiveAdSize(width: width))
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        context.coordinator.updateAdSizeIfNeeded(
            AdBannerMetrics.anchoredAdaptiveAdSize(width: width),
            on: uiView
        )
    }
}

extension AdBannerView {
    final class Coordinator {
        private var lastLoadedSize: CGSize?

        func makeBanner(adSize: AdSize) -> BannerView {
            let banner = BannerView(adSize: adSize)
            #if DEBUG
            banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
            #else
            banner.adUnitID = "ca-app-pub-9676260030977388/3254679876"
            #endif
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                banner.rootViewController = rootVC
            }
            return banner
        }

        func updateAdSizeIfNeeded(_ adSize: AdSize, on banner: BannerView) {
            let size = adSize.size
            if lastLoadedSize == size {
                return
            }
            lastLoadedSize = size
            banner.adSize = adSize
            banner.load(Request())
        }
    }
}
