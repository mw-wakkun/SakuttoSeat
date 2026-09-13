//
//  VenueSettingsPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5
//  広告視聴後の列数適用を Presenter + Router の連携に整理し、
//  結果は Output で親（SeatingChartPresenter）へ通知する。
//  refactor_Ad.md Phase 4（リワード分岐を await 可能なメソッドに切り出し、テストから駆動する）
//  v2.0 hotfix（視聴成功後は解放→列数適用→親通知まで切らない。UI は Main）
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

    /// 広告待ちなど、画面寿命を超えて走らないようにする非同期作業。
    private var runningTask: Task<Void, Never>?
    /// 閉じたあとに完了した広告待ちが副作用を残さないための世代。
    private var runningTaskID = UUID()

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

        startRunningTask { [weak self] in
            await self?.confirmWatchAd(requestedColumnCount: requested)
        }
    }

    /// 広告提示の結果を解放 / Output / Route へ写す。View は `didConfirmWatchAd` 経由。テストはここを await する。
    /// 視聴成功後はセッション解放と列数適用を Main で行い、親へ通知する。
    func confirmWatchAd(requestedColumnCount: Int) async {
        let taskID = runningTaskID
        do {
            try await router.presentRewardedAd()
            guard isCurrentTask(taskID) else { return }
            await applyRewardedColumnUnlock(columnCount: requestedColumnCount)
        } catch RewardedAdError.notReady {
            guard isCurrentTask(taskID) else { return }
            route = .adNotReady
        } catch {
            // notEarned / failed / キャンセル: 解放しない
        }
    }

    /// 視聴完了後の解放・列数適用・親への通知。UI 更新は Main で行う。
    private func applyRewardedColumnUnlock(columnCount: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { [self] in
                interactor.grantSessionUnlock()
                _ = interactor.select(columnCount)
                publishState()
                output?.venueSettingsDidApply(columnCount: columnCount)
                continuation.resume()
            }
        }
    }

    func dismissRoute() {
        cancelRunningTask()
        route = nil
    }

    /// シートや画面が閉じられたときに、広告待ちなどの非同期作業を破棄する。
    func cancelRunningTask() {
        runningTask?.cancel()
        runningTask = nil
        runningTaskID = UUID()
    }

    private func publishState() {
        viewData = Self.makeViewData(from: interactor)
    }

    private func startRunningTask(_ operation: @escaping @MainActor () async -> Void) {
        runningTask?.cancel()
        runningTaskID = UUID()
        runningTask = Task { @MainActor in
            await operation()
        }
    }

    private func isCurrentTask(_ taskID: UUID) -> Bool {
        runningTaskID == taskID && !Task.isCancelled
    }

    private static func makeViewData(from interactor: VenueSettingsInteractor) -> VenueSettingsViewData {
        VenueSettingsViewData(
            selectedColumnCount: interactor.selectedColumnCount,
            selectableRange: interactor.selectableRange,
            noticeText: VenueExpansionCopy.venueNotice,
            requiresUnlock: interactor.applyRequirement() == .rewardedAd
        )
    }
}
