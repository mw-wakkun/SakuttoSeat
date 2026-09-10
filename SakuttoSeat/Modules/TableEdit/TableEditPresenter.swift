//
//  TableEditPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5
//  編集中の値は Presenter が ViewData として保持する（View の @State 焼き込みを廃止）。
//

import Combine
import Foundation

@MainActor
final class TableEditPresenter: ObservableObject, TableEditPresenterProtocol {
    @Published private(set) var viewData: TableEditViewData

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: TableEditInteractor
    private weak var output: (any TableEditModuleOutput)?

    init(interactor: TableEditInteractor, output: (any TableEditModuleOutput)?) {
        self.interactor = interactor
        self.output = output
        self.viewData = Self.makeViewData(from: interactor)
    }

    func didChangeName(_ name: String) {
        interactor.updateName(name)
        publishState()
    }

    func didChangeCapacity(_ capacity: Int) {
        interactor.updateCapacity(capacity)
        publishState()
    }

    func didChangeColumnCount(_ columnCount: Int) {
        interactor.updateColumnCount(columnCount)
        publishState()
    }

    func didSelectLayoutDirection(_ direction: LayoutDirection) {
        interactor.updateLayoutDirection(direction)
        publishState()
    }

    func didChangeLayoutText(_ text: String) {
        interactor.updateLayoutText(text)
        publishState()
    }

    func didToggleApplyToAllTables(_ isOn: Bool) {
        interactor.updateApplyToAllTables(isOn)
        publishState()
    }

    func didTapSave() {
        output?.tableEditDidCommit(interactor.makeUpdateRequest())
    }

    func didTapDelete() {
        output?.tableEditDidRequestDelete(tableID: interactor.draft.tableID)
    }

    func didTapCancel() {
        output?.tableEditDidCancel()
    }

    private func publishState() {
        viewData = Self.makeViewData(from: interactor)
    }

    private static func makeViewData(from interactor: TableEditInteractor) -> TableEditViewData {
        let draft = interactor.draft
        return TableEditViewData(
            name: draft.name,
            capacity: draft.capacity,
            capacityRange: interactor.capacityRange,
            columnCount: draft.columnCount,
            columnCountRange: interactor.columnCountRange,
            layoutDirection: draft.layoutDirection,
            layoutText: draft.layoutText,
            applyToAllTables: draft.applyToAllTables,
            maxInputLength: interactor.maxInputLength,
            layoutTextPresets: interactor.layoutTextPresets
        )
    }
}
