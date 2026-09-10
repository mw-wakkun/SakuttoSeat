//
//  VenueSettingsRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子モジュールの組み立てと広告提示）
//

import SwiftUI

final class VenueSettingsRouter: VenueSettingsRouterProtocol {

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
        let router = VenueSettingsRouter()
        let presenter = VenueSettingsPresenter(interactor: interactor, router: router, output: output)
        return AnyView(VenueSettingsView(presenter: presenter))
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await RewardedAdPresenter.present()
    }
}
