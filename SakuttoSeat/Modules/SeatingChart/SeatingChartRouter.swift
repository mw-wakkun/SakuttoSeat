//
//  SeatingChartRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（遷移・提示・子モジュール組み立て）
//  Phase 5（共有・広告の提示は Share モジュールへ移管し、ここは子モジュール組立に専念）
//  refactor_templateListView.md Phase 3（テンプレート子は gatewayHolder から現行 Gateway を読む）
//  refactor_templateListView.md Phase 4（子 Presenter の組み立てとシート View を分離。キャッシュは親）
//  v2.1 Phase 3（発表 Cover の組み立てとアイドルタイマ）
//

import SwiftUI

final class SeatingChartRouter: SeatingChartRouterProtocol {

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let rewardedAd: RewardedAdGatewayBase

    init(rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayBase()) {
        self.rewardedAd = rewardedAd
    }

    /// モジュールの組み立て（Builder 相当）。
    /// 本番は App が SwiftData Gateway を渡す。Preview / テストはデフォルトの InMemory。
    @MainActor
    static func assembleModule(
        attendees: [Attendee],
        templateGateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway()
    ) -> AnyView {
        let interactor = SeatingChartInteractor(
            attendees: attendees,
            featureUnlock: SessionFeatureUnlock.shared,
            templateGateway: templateGateway
        )
        let router = SeatingChartRouter(rewardedAd: SessionRewardedAd.shared)
        let presenter = SeatingChartPresenter(interactor: interactor, router: router)
        return AnyView(SeatingChartView(presenter: presenter))
    }

    // MARK: - 子モジュールの組み立て

    @MainActor
    func makeTableEditModule(
        draft: TableEditDraft,
        attendeeCount: Int,
        tableCapacities: [TableID: Int],
        output: (any TableEditModuleOutput)?
    ) -> AnyView {
        TableEditRouter.assembleModule(
            draft: draft,
            attendeeCount: attendeeCount,
            tableCapacities: tableCapacities,
            output: output
        )
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
    func makeTemplateListPresenter(
        gatewayHolder: SeatingChartInteractor,
        output: (any SeatingTemplateModuleOutput)?
    ) -> SeatingTemplatePresenter {
        SeatingTemplateRouter.assemblePresenter(
            gateway: gatewayHolder.currentTemplateGateway(),
            output: output
        )
    }

    @MainActor
    func makeTemplateListSheet(presenter: SeatingTemplatePresenter) -> AnyView {
        SeatingTemplateRouter.assembleView(presenter: presenter)
    }

    @MainActor
    func makePresentationCover(
        subject: PresentationSubject,
        onDismiss: @escaping () -> Void
    ) -> AnyView {
        AnyView(PresentationCanvas(subject: subject, onDismiss: onDismiss))
    }

    @MainActor
    func setIdleTimerDisabled(_ disabled: Bool) {
        IdleTimerController.setDisabled(disabled)
    }

    @MainActor
    func waitUntilPresentable() async {
        await ShareSheetPresenter.waitUntilPresentable()
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await rewardedAd.present()
    }
}
