//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4 / Phase 5
//  refactor_templateListView.md Phase 3（シート組み立ては gatewayHolder。Presenter は Gateway 型を渡さない）
//  refactor_templateListView.md Phase 4（`.templateList` 期間中は子 Presenter を 1 度だけ保持）
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

    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase) {
        interactor.attachTemplateGateway(gateway)
    }

    func onAppear() {}

    func didTapAddTable() {
        _ = interactor.addTable()
        publishState()
    }

    func didTapTable(id: TableID) {
        guard interactor.currentTables().contains(where: { $0.id == id }) else { return }
        setRoute(.tableEdit(id))
    }

    func didTapSeat(tableID: TableID, memberID: MemberID) {
        _ = interactor.toggleLock(tableID: tableID, memberID: memberID)
        publishState()
    }

    func didTapShuffle() {
        _ = interactor.shuffleSeats()
        publishState()
    }

    func didTapSaveTemplate() {
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
        templateListPresenter = router.makeTemplateListPresenter(
            gatewayHolder: interactor,
            output: self
        )
        setRoute(.templateList)
    }

    /// 共有はタップ時点の表示内容を Share モジュールへ渡すだけ
    func didTapShare() {
        share.didTapShare(subject: .seatingChart(viewData))
    }

    func didTapSettings() { setRoute(.venueSettings) }
    func dismissRoute() { setRoute(nil) }

    /// シート内容を Router 経由で組み立てる（View から子モジュールの組立を排除）
    func makeRouteSheet(_ route: SeatingChartRoute) -> AnyView {
        switch route {
        case .tableEdit(let tableID):
            guard let draft = interactor.tableEditDraft(for: tableID) else {
                return AnyView(EmptyView())
            }
            return router.makeTableEditModule(draft: draft, output: self)
        case .venueSettings:
            return router.makeVenueSettingsModule(
                currentColumnCount: interactor.currentVenueSettings().globalColumnCount,
                featureUnlock: interactor.featureUnlock,
                output: self
            )
        case .templateList:
            return router.makeTemplateListSheet(presenter: templateListSheetPresenter())
        case .saveTemplatePrompt, .alert:
            return AnyView(EmptyView())
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
            globalColumnCount: interactor.currentVenueSettings().globalColumnCount
        )
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

    /// `.templateList` 以外へ移るときは子 Presenter を破棄する。
    private func setRoute(_ newRoute: SeatingChartRoute?) {
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
