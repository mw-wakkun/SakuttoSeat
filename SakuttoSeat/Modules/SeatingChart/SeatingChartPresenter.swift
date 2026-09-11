//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4 / Phase 5
//  refactor_templateListView.md Phase 2（一覧は子 VIPER。選択は ID。閉じるは Output）
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
        route = .tableEdit(id)
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
            route = .saveTemplatePrompt
        case .limitReached(let currentCount, let limit):
            route = .alert(.templateLimitReached(currentCount: currentCount, limit: limit))
        }
    }

    func didConfirmSaveTemplate(name: String) {
        do {
            try interactor.saveCurrentLayoutAsTemplate(named: name)
            route = nil
        } catch let error as TemplateSaveError {
            switch error {
            case .limitReached(let currentCount, let limit):
                route = .alert(.templateLimitReached(currentCount: currentCount, limit: limit))
            case .invalidName, .emptyLayout, .notFound:
                route = nil
            case .persistenceFailed(let message):
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didTapLoadTemplate() { route = .templateList }

    /// 共有はタップ時点の表示内容を Share モジュールへ渡すだけ
    func didTapShare() {
        share.didTapShare(subject: .seatingChart(viewData))
    }

    func didTapSettings() { route = .venueSettings }
    func dismissRoute() { route = nil }

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
            return router.makeTemplateListModule(
                gateway: interactor.currentTemplateGateway(),
                output: self
            )
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
}

// MARK: - 子モジュール Output

extension SeatingChartPresenter: TableEditModuleOutput {
    func tableEditDidCommit(_ request: TableUpdateRequest) {
        didCommitTableEdit(request)
        route = nil
    }

    func tableEditDidRequestDelete(tableID: TableID) {
        didRequestDeleteTable(id: tableID)
        route = nil
    }

    func tableEditDidCancel() {
        route = nil
    }
}

extension SeatingChartPresenter: VenueSettingsModuleOutput {
    func venueSettingsDidApply(columnCount: Int) {
        globalColumnCount = columnCount
        route = nil
    }
}

extension SeatingChartPresenter: SeatingTemplateModuleOutput {
    func templateListDidSelect(id: SeatingTemplateID) {
        do {
            _ = try interactor.loadAndApplyTemplate(id: id)
            canvasEvent = .scrollToTop()
            publishState()
            route = nil
        } catch TemplateSaveError.notFound {
            return
        } catch let error as TemplateSaveError {
            if case .persistenceFailed(let message) = error {
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func templateListDidCancel() {
        route = nil
    }
}
