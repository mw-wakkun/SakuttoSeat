//
//  RewardedAdPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（リワード広告提示の async ラッパ）
//  refactor_Ad.md Phase 1（RewardedAdError を Core/Entity へ移設。本型の削除は Phase 2）
//

import Foundation

@MainActor
enum RewardedAdPresenter {
    /// 準備済みなら提示し、dismiss 時に earned / notEarned / failed で完了する
    static func present() async throws {
        let manager = RewardedAdManager.shared
        guard manager.isAdReady else {
            manager.loadAd()
            throw RewardedAdError.notReady
        }
        try await manager.presentAsync()
    }
}
