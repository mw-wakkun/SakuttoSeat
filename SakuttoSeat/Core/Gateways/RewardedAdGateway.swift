//
//  RewardedAdGateway.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 0（契約の固定）
//  refactor_Ad.md Phase 2（具象 Base。Router は existential ではなくこれを保持する）
//  refactor_Ad.md Phase 3（preload は App の start 完了後）
//

import Foundation

/// リワード広告のロード状態。Interactor からも読めるよう nonisolated。
/// `preload()` は `MobileAds.shared.start()` 完了後に App から呼ぶ（Phase 3）。
nonisolated protocol RewardedAdGateway: AnyObject {
    var isReady: Bool { get }
    func preload()
}

/// リワード広告のフルスクリーン提示。UIKit 提示のため Router から MainActor で呼ぶ。
protocol RewardedAdPresenting: AnyObject {
    @MainActor func present() async throws
}

/// Protocol existential をクラスが保持すると deinit で malloc abort するため、
/// Router は具象基底クラスだけを保持する（`GroupFavoriteGatewayBase` と同じ）。
/// `NSObject`: 本番 Impl が `FullScreenContentDelegate` を満たすため。
nonisolated class RewardedAdGatewayBase: NSObject, RewardedAdGateway, RewardedAdPresenting {
    var isReady: Bool = false

    func preload() {}

    @MainActor
    func present() async throws {
        throw RewardedAdError.notReady
    }
}
