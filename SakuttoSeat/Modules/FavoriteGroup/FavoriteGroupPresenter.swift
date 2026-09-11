//
//  FavoriteGroupPresenter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//

import Combine
import Foundation

@MainActor
final class FavoriteGroupPresenter: ObservableObject, FavoriteGroupPresenterProtocol {
    @Published private(set) var viewData: FavoriteGroupViewData = .empty
    @Published var alert: FavoriteGroupAlert?

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: FavoriteGroupInteractor
    private weak var output: (any FavoriteGroupModuleOutput)?

    init(interactor: FavoriteGroupInteractor, output: (any FavoriteGroupModuleOutput)?) {
        self.interactor = interactor
        self.output = output
        publishState()
    }

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        interactor.attachFavoriteGateway(gateway)
        publishState()
    }

    func onAppear() {
        publishState()
    }

    func didSelectGroup(id: FavoriteGroupID) {
        output?.favoriteGroupDidSelect(id: id)
    }

    func didDeleteGroups(at offsets: IndexSet) {
        do {
            try interactor.deleteFavorites(at: offsets)
            publishState()
        } catch let error as FavoriteSaveError {
            if case .persistenceFailed(let message) = error {
                alert = .deleteFailed(message: message)
            }
        } catch {
            alert = .deleteFailed(message: error.localizedDescription)
        }
    }

    func didTapClose() {
        output?.favoriteGroupDidCancel()
    }

    func dismissAlert() {
        alert = nil
    }

    private func publishState() {
        let groups = interactor.allFavorites()
        viewData = FavoriteGroupViewData(groups: groups, isEmpty: groups.isEmpty)
    }
}
