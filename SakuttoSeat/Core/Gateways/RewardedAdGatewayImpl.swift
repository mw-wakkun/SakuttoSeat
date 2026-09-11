//
//  RewardedAdGatewayImpl.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 2（RewardedAdManager の移植。報酬競合の是正は Phase 3）
//

import Foundation
import GoogleMobileAds
import UIKit

final class RewardedAdGatewayImpl: RewardedAdGatewayBase, FullScreenContentDelegate {
    private var rewardedAd: RewardedAd?
    private var hasEarnedReward = false
    private var presentContinuation: CheckedContinuation<Void, Error>?

    fileprivate override init() {
        super.init()
        preload()
    }

    override func preload() {
        loadAd()
    }

    /// 準備済みなら提示し、dismiss 時に earned / notEarned / failed で完了する。
    /// 旧 `RewardedAdPresenter.present()` の判定をここに吸収した。
    @MainActor
    override func present() async throws {
        guard isReady else {
            preload()
            throw RewardedAdError.notReady
        }
        try await presentAsync()
    }

    private func loadAd() {
        let request = Request()
        RewardedAd.load(with: AdConfiguration.rewardedUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = error {
                    print("リワード広告読み込み失敗: \(error.localizedDescription)")
                    self.isReady = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isReady = true
                print("リワード広告の準備が完了しました")
            }
        }
    }

    /// dismiss 完了時に earned → return / notEarned・failed → throw
    @MainActor
    private func presentAsync() async throws {
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
        isReady = false

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

/// アプリ起動中だけ有効なリワード Gateway。assemble と App の preload 専用。
/// 機能 View / Presenter は触らない（`SessionFeatureUnlock` と同じ）。
enum SessionRewardedAd {
    static let shared = RewardedAdGatewayImpl()
}
