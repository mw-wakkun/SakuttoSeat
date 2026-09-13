//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4 / Phase 5
//  refactor_templateListView.md Phase 3（シート組み立ては gatewayHolder。Presenter は Gateway 型を渡さない）
//  refactor_templateListView.md Phase 4（`.templateList` 期間中は子 Presenter を 1 度だけ保持）
//  v2.1 Phase 3（didTapPresent。発表中は share / shuffle の Route を出さない）
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class SeatingChartPresenter: ObservableObject, SeatingChartPresenterProtocol {
    @Published private(set) var viewData: SeatingChartViewData = .empty
    @Published var route: SeatingChartRoute?
    @Published var canvasEvent: SeatingChartCanvasEvent?

    /// 共有フロー（Share モジュール）。View は `.shareFlow(presenter.share)` で取り付ける。
    let share: SharePresenter

    var globalColumnCount: Int {
        get { interactor.currentVenueSettings().globalColumnCount }
        set {
            _ = try? interactor.applyColumnCount(newValue)
            publishState()
        }
    }

    var sessionUnlockedColumns: Bool {
        get { interactor.isSessionUnlocked }
        set {
            if newValue { interactor.grantSessionUnlock() }
            objectWillChange.send()
        }
    }

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: SeatingChartInteractor
    private let router: SeatingChartRouter

    /// 広告待ちなど、画面寿命を超えて走らないようにする非同期作業。
    private var runningTask: Task<Void, Never>?
    private var runningTaskID = UUID()

    /// `.templateList` 期間中だけ保持する。
    /// `.sheet(item:)` の content 再評価で再 assemble すると子の alert / 編集中状態が消えるため。
    /// `didTapLoadTemplate` のたびに新規 assemble、閉じたら破棄（Gateway 差し替え後の stale を防ぐ）。
    private(set) var templateListPresenter: SeatingTemplatePresenter?

    init(
        interactor: SeatingChartInteractor,
        router: SeatingChartRouter,
        share: SharePresenter? = nil
    ) {
        self.interactor = interactor
        self.router = router
        self.share = share ?? ShareRouter.assemblePresenter()
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける
    /// （子 Presenter が Output の protocol existential を弱参照するため。AttendeeListPresenter と同じ）
    nonisolated deinit {}

    func didTapAddTable() {
        guard !isPresenting else { return }
        switch interactor.tableAddDecision(additionalCapacity: nil) {
        case .allowed:
            _ = interactor.addTable()
            publishState()
        case .requiresUnlock:
            setRoute(.alert(.venueUnlock))
        case .blockedHardLimit(let reason):
            switch reason {
            case .table:
                setRoute(.alert(.tableHardLimit))
            case .totalSeat:
                setRoute(.alert(.totalSeatHardLimit))
            case .attendee:
                setRoute(.alert(.tableHardLimit))
            }
        }
    }

    func didConfirmWatchVenueAd() {
        setRoute(nil)
        startRunningTask { [weak self] in
            await self?.confirmWatchVenueAd()
        }
    }

    /// 卓追加の視聴結果。テストはここを await する。
    func confirmWatchVenueAd() async {
        setRoute(nil)
        let taskID = runningTaskID
        do {
            await router.waitUntilPresentable()
            guard isCurrentTask(taskID) else { return }
            try await router.presentRewardedAd()
            guard isCurrentTask(taskID) else { return }
            interactor.grantSessionUnlock()
            _ = interactor.addTable()
            publishState()
        } catch RewardedAdError.notReady {
            guard isCurrentTask(taskID) else { return }
            setRoute(.alert(.adNotReady))
        } catch {
            // notEarned / failed / キャンセル: 卓は足さない
        }
    }

    func didTapTable(id: TableID) {
        guard !isPresenting else { return }
        guard interactor.currentTables().contains(where: { $0.id == id }) else { return }
        setRoute(.tableEdit(id))
    }

    func didTapSeat(tableID: TableID, memberID: MemberID) {
        guard !isPresenting else { return }
        _ = interactor.toggleLock(tableID: tableID, memberID: memberID)
        publishState()
    }

    func didTapShuffle() {
        guard !isPresenting else { return }
        _ = interactor.shuffleSeats()
        publishState()
    }

    func didTapSaveTemplate() {
        guard !isPresenting else { return }
        switch interactor.templateSaveAvailability() {
        case .available:
            setRoute(.saveTemplatePrompt)
        case .limitReached(let currentCount, let limit):
            setRoute(.alert(.templateLimitReached(currentCount: currentCount, limit: limit)))
        }
    }

    func didConfirmSaveTemplate(name: String) {
        do {
            try interactor.saveCurrentLayoutAsTemplate(named: name)
            setRoute(nil)
        } catch let error as TemplateSaveError {
            switch error {
            case .limitReached(let currentCount, let limit):
                setRoute(.alert(.templateLimitReached(currentCount: currentCount, limit: limit)))
            case .invalidName, .emptyLayout, .notFound:
                setRoute(nil)
            case .persistenceFailed(let message):
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }

    func didTapLoadTemplate() {
        guard !isPresenting else { return }
        templateListPresenter = router.makeTemplateListPresenter(
            gatewayHolder: interactor,
            output: self
        )
        setRoute(.templateList)
    }

    /// 共有はタップ時点の表示内容を Share モジュールへ渡すだけ
    func didTapShare() {
        guard !isPresenting else { return }
        share.didTapShare(subject: .seatingChart(viewData))
    }

    /// 発表はタップ時点の ViewData を凍結して Cover する
    func didTapPresent() {
        guard viewData.isShareEnabled, !isPresenting else { return }
        setRoute(.presentation(id: UUID(), snapshot: viewData))
    }

    func didTapSettings() {
        guard !isPresenting else { return }
        setRoute(.venueSettings)
    }

    func dismissRoute() {
        cancelRunningTask()
        setRoute(nil)
    }

    /// シート内容を Router 経由で組み立てる（View から子モジュールの組立を排除）
    func makeRouteSheet(_ route: SeatingChartRoute) -> AnyView {
        switch route {
        case .tableEdit(let tableID):
            guard let draft = interactor.tableEditDraft(for: tableID) else {
                return AnyView(EmptyView())
            }
            return router.makeTableEditModule(
                draft: draft,
                attendeeCount: interactor.currentAttendeeCount(),
                tableCapacities: interactor.currentTableCapacities(),
                output: self
            )
        case .venueSettings:
            return router.makeVenueSettingsModule(
                currentColumnCount: interactor.currentVenueSettings().globalColumnCount,
                featureUnlock: interactor.featureUnlock,
                output: self
            )
        case .templateList:
            return router.makeTemplateListSheet(presenter: templateListSheetPresenter())
        case .saveTemplatePrompt, .alert, .presentation:
            return AnyView(EmptyView())
        }
    }

    /// 発表 Cover を Router 経由で組み立てる（空の VIPER は作らない）
    func makePresentationCover(_ route: SeatingChartRoute) -> AnyView {
        guard case .presentation(_, let snapshot) = route else {
            return AnyView(EmptyView())
        }
        return router.makePresentationCover(subject: .seatingChart(snapshot)) { [weak self] in
            self?.dismissRoute()
        }
    }

    func didCommitTableEdit(_ request: TableUpdateRequest) {
        _ = interactor.applyTableUpdate(request)
        canvasEvent = .scrollToTop()
        publishState()
    }

    func didRequestDeleteTable(id: TableID) {
        _ = interactor.deleteTable(id: id)
        publishState()
    }

    private func publishState() {
        viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: interactor.currentVenueSettings().globalColumnCount,
            addTableDecision: interactor.tableAddDecision(additionalCapacity: nil)
        )
    }

    private func startRunningTask(_ operation: @escaping @MainActor () async -> Void) {
        runningTask?.cancel()
        runningTaskID = UUID()
        runningTask = Task { @MainActor in
            await operation()
        }
    }

    private func cancelRunningTask() {
        runningTask?.cancel()
        runningTask = nil
        runningTaskID = UUID()
    }

    private func isCurrentTask(_ taskID: UUID) -> Bool {
        runningTaskID == taskID && !Task.isCancelled
    }

    /// `didTapLoadTemplate` で assemble 済みならそれを返す。未セットならここで 1 度だけ作る。
    private func templateListSheetPresenter() -> SeatingTemplatePresenter {
        if let templateListPresenter {
            return templateListPresenter
        }
        let assembled = router.makeTemplateListPresenter(
            gatewayHolder: interactor,
            output: self
        )
        templateListPresenter = assembled
        return assembled
    }

    private var isPresenting: Bool {
        route?.presentsAsFullScreenCover == true
    }

    /// `.templateList` 以外へ移るときは子 Presenter を破棄する。
    /// 発表の開始/終了でアイドルタイマを切り替える。
    private func setRoute(_ newRoute: SeatingChartRoute?) {
        let wasPresenting = route?.presentsAsFullScreenCover == true
        let willPresent = newRoute?.presentsAsFullScreenCover == true
        if wasPresenting != willPresent {
            router.setIdleTimerDisabled(willPresent)
        }
        if newRoute != .templateList {
            templateListPresenter = nil
        }
        route = newRoute
    }
}

// MARK: - 子モジュール Output

extension SeatingChartPresenter: TableEditModuleOutput {
    func tableEditDidCommit(_ request: TableUpdateRequest) {
        didCommitTableEdit(request)
        setRoute(nil)
    }

    func tableEditDidRequestDelete(tableID: TableID) {
        didRequestDeleteTable(id: tableID)
        setRoute(nil)
    }

    func tableEditDidCancel() {
        setRoute(nil)
    }
}

extension SeatingChartPresenter: VenueSettingsModuleOutput {
    func venueSettingsDidApply(columnCount: Int) {
        globalColumnCount = columnCount
        setRoute(nil)
    }
}

extension SeatingChartPresenter: SeatingTemplateModuleOutput {
    func templateListDidSelect(id: SeatingTemplateID) {
        do {
            _ = try interactor.loadAndApplyTemplate(id: id)
            canvasEvent = .scrollToTop()
            publishState()
            setRoute(nil)
        } catch TemplateSaveError.notFound {
            return
        } catch let error as TemplateSaveError {
            if case .persistenceFailed(let message) = error {
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }

    func templateListDidCancel() {
        setRoute(nil)
    }
}
