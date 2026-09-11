//
//  AdBannerContainer.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 6（画面側の 320×50 固定を廃止し、幅に追従する）
//  番号札のように inset 内がバナーだけの画面では、子の ideal 幅が 0 になり
//  PreferenceKey では計測できない。containerRelativeFrame で親幅を確定する。
//  refactor_Ad.md Phase 1（AdBannerView と Components に同居。公開 API はこの Container）
//  refactor_Ad.md Phase 5（上下余白を Container 内に閉じる。Representable は fileprivate）
//

import GoogleMobileAds
import SwiftUI

/// 親の幅に合わせたアダプティブバナー。VoiceOver では広告を飛ばして操作できるように隠す。
/// 機能 View が置いてよい唯一の広告 UI。SDK / ユニット ID / Representable は知らない。
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
        .padding(.vertical, AppSpacing.bannerVerticalPadding)
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

/// バナー広告のサイズ計算。機能 View は使わない。テストは `@testable import` で参照する。
enum AdBannerMetrics {
    static func size(forWidth width: CGFloat) -> CGSize {
        anchoredAdaptiveAdSize(width: width).size
    }

    /// 直前に load したサイズと同じなら再 load しない。
    /// 幅・高さは pt 単位に丸めて比較し、小数点の揺れで過剰 reload しない。
    static func shouldReloadBanner(previous: CGSize?, next: CGSize) -> Bool {
        guard let previous else { return true }
        return roundedPointSize(previous) != roundedPointSize(next)
    }

    fileprivate static func anchoredAdaptiveAdSize(width: CGFloat) -> AdSize {
        // large（50〜150pt）だとボトムクロムが高すぎる。
        // 標準アンカーは旧 320×50 相当（高さ 50〜90pt）。GMA 13 では deprecated だが残っている。
        currentOrientationAnchoredAdaptiveBanner(width: max(width, 1))
    }

    private static func roundedPointSize(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.rounded(), height: size.height.rounded())
    }
}

/// 公開 API ではない。`AdBannerContainer` 経由でのみ使う。
fileprivate struct AdBannerView: UIViewRepresentable {
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

    /// BannerView の intrinsic サイズが SwiftUI の親を押し広げないようにする。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BannerView, context: Context) -> CGSize? {
        AdBannerMetrics.size(forWidth: width)
    }
}

extension AdBannerView {
    final class Coordinator: NSObject, BannerViewDelegate {
        private var lastLoadedSize: CGSize?
        private var loadGeneration = 0

        /// load はしない。初回 load は `updateUIView` → `updateAdSizeIfNeeded` の単一路。
        func makeBanner(adSize: AdSize) -> BannerView {
            let banner = BannerView(adSize: adSize)
            banner.adUnitID = AdConfiguration.bannerUnitID
            banner.delegate = self
            return banner
        }

        /// サイズが実質同一なら load しない。失敗時の自動リトライもしない。
        func updateAdSizeIfNeeded(_ adSize: AdSize, on banner: BannerView) {
            let size = adSize.size
            guard AdBannerMetrics.shouldReloadBanner(previous: lastLoadedSize, next: size) else {
                return
            }
            lastLoadedSize = size
            banner.adSize = adSize
            loadGeneration += 1
            let generation = loadGeneration
            Task { @MainActor [weak self, weak banner] in
                await self?.loadBanner(banner, generation: generation)
            }
        }

        @MainActor
        private func loadBanner(_ banner: BannerView?, generation: Int) async {
            guard let banner, loadGeneration == generation else { return }

            // start() 完了前の load は「SDK tried to perform a networking task before being initialized」で
            // 失敗し、同じサイズでは再試行されない。App の Gateway preload と二重でも安全。
            // Phase 3: バナー側の start() 待ちは外さない。
            _ = await MobileAds.shared.start()
            guard loadGeneration == generation else { return }

            guard let rootViewController = await resolveRootViewController() else {
                #if DEBUG
                print("バナー広告: rootViewController が取れないため load を延期します")
                #endif
                lastLoadedSize = nil
                return
            }
            banner.rootViewController = rootViewController
            banner.load(Request())
        }

        /// 起動直後は keyWindow がまだ無いことがあるので、Share シートと同じく短く待つ。
        @MainActor
        private func resolveRootViewController() async -> UIViewController? {
            let timeoutNanoseconds: UInt64 = 2_000_000_000
            let started = DispatchTime.now().uptimeNanoseconds
            while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
                if let viewController = rootViewController() {
                    return viewController
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return rootViewController()
        }

        private func rootViewController() -> UIViewController? {
            if let top = UIApplication.shared.topViewController {
                return top
            }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            return scene?.windows.first { $0.isKeyWindow }?.rootViewController
                ?? scene?.windows.first?.rootViewController
        }

        /// 失敗は握る。自動リトライはしない。次のサイズ変更または Representable 再生成で再試行する。
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("バナー広告読み込み失敗: \(error.localizedDescription)")
            #endif
        }
    }
}
