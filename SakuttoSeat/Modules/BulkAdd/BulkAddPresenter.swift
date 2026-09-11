//
//  BulkAddPresenter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  入力は Presenter が ViewData として保持する。確定テキストだけ親へ返す。
//

import Combine
import Foundation

@MainActor
final class BulkAddPresenter: ObservableObject, BulkAddPresenterProtocol {
    @Published private(set) var viewData: BulkAddViewData = .empty

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: BulkAddInteractor
    private weak var output: (any BulkAddModuleOutput)?

    init(interactor: BulkAddInteractor = BulkAddInteractor(), output: (any BulkAddModuleOutput)?) {
        self.interactor = interactor
        self.output = output
        publishState()
    }

    func didChangeText(_ text: String) {
        interactor.updateText(text)
        publishState()
    }

    func didTapConfirm() {
        guard interactor.canConfirm else { return }
        output?.bulkAddDidConfirm(text: interactor.text)
    }

    func didTapCancel() {
        output?.bulkAddDidCancel()
    }

    private func publishState() {
        viewData = BulkAddViewData(
            text: interactor.text,
            canConfirm: interactor.canConfirm,
            delimiterHint: interactor.delimiterHint
        )
    }
}
