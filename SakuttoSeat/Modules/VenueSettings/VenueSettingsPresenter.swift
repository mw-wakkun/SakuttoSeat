//
//  VenueSettingsPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5
//  広告視聴後の列数適用を Presenter + Router の連携に整理し、
//  結果は Output で親（SeatingChartPresenter）へ通知する。
//

import Combine
import Foundation

@MainActor
final class VenueSettingsPresenter: ObservableObject, VenueSettingsPresenterProtocol {
    @Published private(set) var viewData: VenueSettingsViewData
    @Published var route: VenueSettingsRoute?

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: VenueSettingsInteractor
    private let router: VenueSettingsRouter
    private weak var output: (any VenueSettingsModuleOutput)?

    init(
        interactor: VenueSettingsInteractor,
        router: VenueSettingsRouter,
        output: (any VenueSettingsModuleOutput)?
    ) {
        self.interactor = interactor
        self.router = router
        self.output = output
        self.viewData = Self.makeViewData(from: interactor)
    }

    func didChangeSelection(_ columnCount: Int) {
        interactor.select(columnCount)
        publishState()
    }

    func didTapApply() {
        switch interactor.applyRequirement() {
        case .none:
            output?.venueSettingsDidApply(columnCount: interactor.selectedColumnCount)
        case .rewardedAd:
            route = .requireUnlock(requested: interactor.selectedColumnCount)
        }
    }

    /// 解放アラートで「動画を視聴して解放」を選んだとき
    func didConfirmWatchAd() {
        route = nil
        let requested = interactor.selectedColumnCount

        Task { @MainActor in
            do {
                try await router.presentRewardedAd()
                interactor.grantSessionUnlock()
                publishState()
                output?.venueSettingsDidApply(columnCount: requested)
            } catch RewardedAdError.notReady {
                route = .adNotReady
            } catch {
                // notEarned / failed: 解放しない
            }
        }
    }

    func dismissRoute() {
        route = nil
    }

    private func publishState() {
        viewData = Self.makeViewData(from: interactor)
    }

    private static func makeViewData(from interactor: VenueSettingsInteractor) -> VenueSettingsViewData {
        VenueSettingsViewData(
            selectedColumnCount: interactor.selectedColumnCount,
            selectableRange: interactor.selectableRange,
            noticeText: "※1〜\(FeatureLimit.freeColumnCount)列は無料で即時利用できます。"
                + "\(FeatureLimit.freeColumnCount + 1)列以上は動画広告視聴による解放が必要です。",
            requiresUnlock: interactor.applyRequirement() == .rewardedAd
        )
    }
}
