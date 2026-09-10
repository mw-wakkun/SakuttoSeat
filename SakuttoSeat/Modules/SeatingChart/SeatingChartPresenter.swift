import Combine
import Foundation
import SwiftUI

@MainActor
final class SeatingChartPresenter: ObservableObject, SeatingChartPresenterProtocol {
    @Published private(set) var viewData: SeatingChartViewData = .empty
    @Published var route: SeatingChartRoute?
    @Published var canvasEvent: SeatingChartCanvasEvent?

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

    init(interactor: SeatingChartInteractor, router: SeatingChartRouter) {
        self.interactor = interactor
        self.router = router
        router.presenter = self
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
            case .invalidName, .emptyLayout:
                route = nil
            case .persistenceFailed(let message):
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didTapLoadTemplate() { route = .templateList }

    func didSelectTemplate(_ template: SeatingLayoutTemplate) {
        applyTemplate(template)
        route = nil
    }

    func didTapShare() { route = .shareSelection }

    func didSelectShareKind(_ kind: ShareSelectionKind) {
        route = nil
        Task { @MainActor in
            await ShareSheetPresenter.waitUntilPresentable()
            switch kind {
            case .text:
                router.presentShareSheet(text: interactor.makeShareText())
            case .image:
                route = .alert(.confirmImageShareWithAd)
            }
        }
    }

    func didRequestImageShare() { route = .alert(.confirmImageShareWithAd) }

    func didConfirmImageShareWithAd(isAdReady: Bool) {
        guard isAdReady else {
            route = .alert(.adNotReady)
            return
        }
        route = nil
        let snapshot = viewData
        Task { @MainActor in
            do {
                try await router.presentRewardedAd()
                let exported = await router.exportAndShareSeatingChart(viewData: snapshot)
                if !exported {
                    route = .alert(.imageExportFailed)
                }
            } catch RewardedAdError.notReady {
                route = .alert(.adNotReady)
            } catch {
                // notEarned / failed: 共有は行わない
            }
        }
    }

    func didTapSettings() { route = .venueSettings }
    func dismissRoute() { route = nil }
    func makeShareText() -> String { interactor.makeShareText() }

    /// シート内容を Router 経由で組み立てる（View から UIKit / 子組立を排除）
    func makeRouteSheet(_ route: SeatingChartRoute) -> AnyView {
        switch route {
        case .tableEdit(let tableID):
            return router.makeTableEditModule(tableID: tableID, output: self)
        case .venueSettings:
            return router.makeVenueSettingsModule(output: self)
        case .templateList:
            return router.makeTemplateListModule(output: self)
        case .shareSelection:
            return AnyView(
                ShareSelectionView { [weak self] kind in
                    self?.didSelectShareKind(kind)
                }
            )
        case .saveTemplatePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    /// TableEdit など子画面が Entity を必要とする間のブリッジ（Phase 5 で廃止）
    func table(for id: TableID) -> SeatingTable? {
        interactor.currentTables().first { $0.id == id }
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

    func applyTemplate(_ template: SeatingLayoutTemplate) {
        let snapshot = LayoutTemplateSnapshot(
            name: template.name, tables: template.tables, globalColumnCount: template.globalColumnCount
        )
        _ = interactor.applyTemplate(snapshot)
        canvasEvent = .scrollToTop()
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

    func venueSettingsDidRequestUnlock(for columnCount: Int) {
        route = .alert(.requireUnlockForColumns(requested: columnCount))
    }
}

extension SeatingChartPresenter: TemplateListModuleOutput {
    func templateListDidSelect(template: SeatingLayoutTemplate) {
        didSelectTemplate(template)
    }

    func templateListDidCancel() {
        route = nil
    }
}
