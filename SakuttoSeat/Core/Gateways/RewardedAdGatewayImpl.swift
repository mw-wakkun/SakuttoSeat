//
//  RewardedAdGatewayImpl.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 2（RewardedAdManager の移植）
//  refactor_Ad.md Phase 3（報酬は同期フラグ。Delegate は MainActor で continuation を resume）
//

import Foundation
import GoogleMobileAds
import UIKit

/// SDK の load / Delegate 完了は Sendable クロージャ。共有状態は `presentationLock` で守る。
nonisolated final class RewardedAdGatewayImpl: RewardedAdGatewayBase, FullScreenContentDelegate, @unchecked Sendable {
    private var rewardedAd: RewardedAd?
    private var isLoadInFlight = false

    /// earned コールバックは MainActor ではないことがある。フラグと continuation は lock で守る。
    private let presentationLock = NSLock()
    private var presentation = RewardedAdPresentationState()
    private var presentContinuation: CheckedContinuation<Void, Error>?

    fileprivate override init() {
        super.init()
        // preload は App の MobileAds.start() 完了後。init では走らせない。
    }

    deinit {
        let (_, continuation) = consumeContinuationAfter { $0.abortIfPresenting() }
        continuation?.resume(throwing: RewardedAdError.failed("広告の提示が中断されました"))
    }

    override func preload() {
        Task { @MainActor in
            await self.loadAdAfterSDKStart()
        }
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

    @MainActor
    private func loadAdAfterSDKStart() async {
        _ = await MobileAds.shared.start()
        loadAd()
    }

    @MainActor
    private func loadAd() {
        let isPresenting = withPresentationLock { presentation.isPresenting }
        guard !isPresenting, !isLoadInFlight, !isReady else { return }
        isLoadInFlight = true
        let request = Request()
        RewardedAd.load(with: AdConfiguration.rewardedUnitID, request: request) { ad, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoadInFlight = false
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
        let alreadyPresenting = withPresentationLock { presentation.isPresenting }
        guard !alreadyPresenting else {
            throw RewardedAdError.failed("すでに広告を提示中です")
        }

        guard let rewardedAd,
              let topViewController = UIApplication.shared.topViewController else {
            print("広告が準備できていないか、画面が見つかりません")
            preload()
            throw RewardedAdError.notReady
        }

        isReady = false

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                withPresentationLock {
                    _ = presentation.beginPresenting()
                    presentContinuation = continuation
                }
                rewardedAd.present(from: topViewController) { [weak self] in
                    // 同期的にフラグを立てる。MainActor hop しない（報酬競合の修正）。
                    self?.markEarnedSynchronously()
                }
            }
        } onCancel: { [self] in
            let (completion, continuation) = consumeContinuationAfter { $0.abortIfPresenting() }
            resume(continuation, with: completion)
        }
    }

    /// userDidEarnReward 用。Task を挟まない。
    private func markEarnedSynchronously() {
        withPresentationLock {
            presentation.markEarned()
        }
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            self?.finishFromDismiss()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishFromFailure(error)
        }
    }

    @MainActor
    private func finishFromDismiss() {
        let (completion, continuation) = consumeContinuationAfter { $0.dismiss() }
        preload()
        resume(continuation, with: completion)
    }

    @MainActor
    private func finishFromFailure(_ error: Error) {
        print("広告表示エラー: \(error.localizedDescription)")
        let (completion, continuation) = consumeContinuationAfter { $0.fail(error.localizedDescription) }
        preload()
        resume(continuation, with: completion)
    }

    private func consumeContinuationAfter(
        _ update: (inout RewardedAdPresentationState) -> RewardedAdPresentationState.Completion
    ) -> (RewardedAdPresentationState.Completion, CheckedContinuation<Void, Error>?) {
        withPresentationLock {
            let completion = update(&presentation)
            guard completion != .alreadyFinished else { return (completion, nil) }
            let continuation = presentContinuation
            presentContinuation = nil
            return (completion, continuation)
        }
    }

    private func resume(
        _ continuation: CheckedContinuation<Void, Error>?,
        with completion: RewardedAdPresentationState.Completion
    ) {
        guard let continuation else { return }
        switch completion {
        case .earned:
            continuation.resume(returning: ())
        case .notEarned:
            continuation.resume(throwing: RewardedAdError.notEarned)
        case .failed(let message):
            continuation.resume(throwing: RewardedAdError.failed(message))
        case .alreadyFinished:
            break
        }
    }

    private func withPresentationLock<T>(_ body: () -> T) -> T {
        presentationLock.lock()
        defer { presentationLock.unlock() }
        return body()
    }
}

/// アプリ起動中だけ有効なリワード Gateway。assemble と App の preload 専用。
/// 機能 View / Presenter は触らない（`SessionFeatureUnlock` と同じ）。
enum SessionRewardedAd {
    static let shared = RewardedAdGatewayImpl()
}
