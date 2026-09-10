//
//  RewardedAdPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（リワード広告提示の async ラッパ）
//

import Foundation

enum RewardedAdError: Error, Equatable {
    /// 広告が未ロード、または提示先 VC が取れない
    case notReady
    /// 視聴は完了したが報酬未獲得のまま閉じた
    case notEarned
    /// 提示自体に失敗した
    case failed(String)
}

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
