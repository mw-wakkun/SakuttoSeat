//
//  SeatingTemplatePresenter.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（ViewData.Row / route。削除は IndexSet → ID）
//

import Combine
import Foundation

@MainActor
final class SeatingTemplatePresenter: ObservableObject, SeatingTemplatePresenterProtocol {
    @Published private(set) var viewData: SeatingTemplateViewData = .empty
    @Published var route: SeatingTemplateRoute?

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: SeatingTemplateInteractor
    private weak var output: (any SeatingTemplateModuleOutput)?

    init(interactor: SeatingTemplateInteractor, output: (any SeatingTemplateModuleOutput)?) {
        self.interactor = interactor
        self.output = output
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける（FavoriteGroupPresenter と同じ）
    nonisolated deinit {}

    func onAppear() {
        publishState()
    }

    func didSelectTemplate(id: SeatingTemplateID) {
        output?.templateListDidSelect(id: id)
    }

    func didDeleteTemplates(at offsets: IndexSet) {
        let ids = offsets.compactMap { offset in
            viewData.rows.indices.contains(offset) ? viewData.rows[offset].id : nil
        }
        guard !ids.isEmpty else { return }

        do {
            try interactor.deleteTemplates(ids: ids)
            publishState()
        } catch let error as TemplateSaveError {
            if case .persistenceFailed(let message) = error {
                route = .alert(.deleteFailed(message: message))
            }
        } catch {
            route = .alert(.deleteFailed(message: error.localizedDescription))
        }
    }

    func didTapClose() {
        output?.templateListDidCancel()
    }

    func dismissRoute() {
        route = nil
    }

    private func publishState() {
        do {
            viewData = SeatingTemplateViewDataBuilder.build(templates: try interactor.allTemplates())
            if case .alert(.loadFailed) = route {
                route = nil
            }
        } catch let error as TemplateSaveError {
            viewData = .empty
            if case .persistenceFailed(let message) = error {
                route = .alert(.loadFailed(message: message))
            }
        } catch {
            viewData = .empty
            route = .alert(.loadFailed(message: error.localizedDescription))
        }
    }
}
