//
//  VenueSettingsRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子モジュールの組み立てと広告提示）
//  refactor_Ad.md Phase 2（リワードは Gateway 具象を assemble 時に注入）
//

import SwiftUI

final class VenueSettingsRouter: VenueSettingsRouterProtocol {

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let rewardedAd: RewardedAdGatewayBase

    init(rewardedAd: RewardedAdGatewayBase) {
        self.rewardedAd = rewardedAd
    }

    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(
        currentColumnCount: Int,
        featureUnlock: FeatureUnlockState,
        output: (any VenueSettingsModuleOutput)?
    ) -> AnyView {
        let interactor = VenueSettingsInteractor(
            currentColumnCount: currentColumnCount,
            featureUnlock: featureUnlock
        )
        let router = VenueSettingsRouter(rewardedAd: SessionRewardedAd.shared)
        let presenter = VenueSettingsPresenter(interactor: interactor, router: router, output: output)
        return AnyView(VenueSettingsView(presenter: presenter))
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await rewardedAd.present()
    }
}
