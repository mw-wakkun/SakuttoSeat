//
//  SeatingChartRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（遷移・提示・子モジュール組み立て）
//  Phase 5（共有・広告の提示は Share モジュールへ移管し、ここは子モジュール組立に専念）
//  refactor_templateListView.md Phase 2（テンプレート一覧は子 VIPER に委譲。identity は Phase 4）
//

import SwiftUI

final class SeatingChartRouter: SeatingChartRouterProtocol {

    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SeatingChartInteractor(
            attendees: attendees,
            featureUnlock: SessionFeatureUnlock.shared
        )
        let router = SeatingChartRouter()
        let presenter = SeatingChartPresenter(interactor: interactor, router: router)
        return AnyView(SeatingChartView(presenter: presenter))
    }

    // MARK: - 子モジュールの組み立て

    @MainActor
    func makeTableEditModule(draft: TableEditDraft, output: (any TableEditModuleOutput)?) -> AnyView {
        TableEditRouter.assembleModule(draft: draft, output: output)
    }

    @MainActor
    func makeVenueSettingsModule(
        currentColumnCount: Int,
        featureUnlock: FeatureUnlockState,
        output: (any VenueSettingsModuleOutput)?
    ) -> AnyView {
        VenueSettingsRouter.assembleModule(
            currentColumnCount: currentColumnCount,
            featureUnlock: featureUnlock,
            output: output
        )
    }

    @MainActor
    func makeTemplateListModule(
        gateway: SeatingTemplateGatewayBase,
        output: (any SeatingTemplateModuleOutput)?
    ) -> AnyView {
        SeatingTemplateRouter.assembleModule(gateway: gateway, output: output)
    }
}
