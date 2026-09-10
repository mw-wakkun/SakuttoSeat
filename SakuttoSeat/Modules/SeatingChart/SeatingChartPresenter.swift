import Combine
import Foundation
import SwiftData

@MainActor
final class SeatingChartPresenter: ObservableObject, SeatingChartPresenterProtocol {
    @Published private(set) var viewData: SeatingChartViewData = .empty
    @Published var route: SeatingChartRoute?
    @Published var canvasEvent: SeatingChartCanvasEvent?
    @Published var pendingShareSelection: ShareSelectionKind?
    @Published var shouldShowAdOnDismiss = false

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

    init(interactor: SeatingChartInteractor, router: SeatingChartRouterProtocol) {
        self.interactor = interactor
        publishState()
        _ = router
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

    func didTapSaveTemplate(canSave: Bool) {
        route = canSave ? .saveTemplatePrompt : .unlockForSave
    }

    func didConfirmSaveTemplate(name: String, context: ModelContext) {
        saveLayoutAsTemplate(templateName: name, context: context)
        route = nil
    }

    func didTapLoadTemplate() { route = .templateList }

    func didSelectTemplate(_ template: SeatingLayoutTemplate) {
        applyTemplate(template)
        route = nil
    }

    func didTapShare() { route = .shareSelection }

    func didSelectShareKind(_ kind: ShareSelectionKind) {
        pendingShareSelection = kind
        route = nil
    }

    func didRequestImageShare() { route = .alert(.confirmImageShareWithAd) }

    func didConfirmImageShareWithAd(isAdReady: Bool, onReward: @escaping () -> Void) {
        guard isAdReady else {
            route = .alert(.adNotReady)
            return
        }
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: onReward)
    }

    func didTapSettings() { route = .venueSettings }
    func dismissRoute() { route = nil }
    func makeShareText() -> String { interactor.makeShareText() }

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

    func saveLayoutAsTemplate(templateName: String, context: ModelContext) {
        guard let snapshot = interactor.makeLayoutTemplate(named: templateName) else { return }
        let template = SeatingLayoutTemplate(
            name: snapshot.name,
            tables: snapshot.tables,
            globalColumnCount: snapshot.globalColumnCount
        )
        context.insert(template)
        do {
            try context.save()
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func canSaveTemplate(context: ModelContext) -> Bool {
        let count = (try? context.fetchCount(FetchDescriptor<SeatingLayoutTemplate>())) ?? 0
        return interactor.templateSaveAvailability(currentCount: count) == .available
    }

    private func publishState() {
        viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: interactor.currentVenueSettings().globalColumnCount
        )
    }
}
