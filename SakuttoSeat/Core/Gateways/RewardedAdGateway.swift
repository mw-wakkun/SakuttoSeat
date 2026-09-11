//
//  RewardedAdGateway.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 0（契約の固定。Router 注入と本番実装の差し替えは Phase 2）
//

import Foundation

/// リワード広告のロード状態。Interactor からも読めるよう nonisolated。
///
/// 本番の `RewardedAdManager` への適合は Phase 2。Phase 0 ではテストダブルが準拠する。
nonisolated protocol RewardedAdGateway: AnyObject {
    var isReady: Bool { get }
    func preload()
}

/// リワード広告のフルスクリーン提示。UIKit 提示のため Router から MainActor で呼ぶ。
protocol RewardedAdPresenting: AnyObject {
    @MainActor func present() async throws
}
