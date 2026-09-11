//
//  RewardedAdManager.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/17.
//  refactor_Ad.md Phase 1（Core/Gateways へ移設。ObservableObject を削除。Impl 化は Phase 2）
//

import Foundation
import GoogleMobileAds
import UIKit

final class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()

    private var rewardedAd: RewardedAd?
    var isAdReady: Bool = false
    private var hasEarnedReward = false
    private var presentContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = Request()
        RewardedAd.load(with: AdConfiguration.rewardedUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = error {
                    print("リワード広告読み込み失敗: \(error.localizedDescription)")
                    self.isAdReady = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                print("リワード広告の準備が完了しました")
            }
        }
    }

    /// dismiss 完了時に earned → return / notEarned・failed → throw
    @MainActor
    func presentAsync() async throws {
        guard presentContinuation == nil else {
            throw RewardedAdError.failed("すでに広告を提示中です")
        }

        guard let rewardedAd,
              let topViewController = UIApplication.shared.topViewController else {
            print("広告が準備できていないか、画面が見つかりません")
            loadAd()
            throw RewardedAdError.notReady
        }

        hasEarnedReward = false
        isAdReady = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.presentContinuation = continuation
            rewardedAd.present(from: topViewController) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.hasEarnedReward = true
                }
            }
        }
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let earned = hasEarnedReward
        hasEarnedReward = false
        let continuation = presentContinuation
        presentContinuation = nil
        loadAd()

        if earned {
            continuation?.resume(returning: ())
        } else {
            continuation?.resume(throwing: RewardedAdError.notEarned)
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("広告表示エラー: \(error.localizedDescription)")
        hasEarnedReward = false
        let continuation = presentContinuation
        presentContinuation = nil
        loadAd()
        continuation?.resume(throwing: RewardedAdError.failed(error.localizedDescription))
    }
}
