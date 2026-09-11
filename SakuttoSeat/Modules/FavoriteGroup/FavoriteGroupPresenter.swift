//
//  FavoriteGroupPresenter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  refactor_favorite.md Phase 1（attach は Interactor のみ。deinit を親と揃える）
//  refactor_favorite.md Phase 2 / Phase 3（ViewData.Row / route。削除は IndexSet → ID）
//  refactor_groupFavorite.md Phase 2（FavoriteSaveError の非 persistenceFailed は明示 default）
//  refactor_groupFavorite.md Phase 3（Builder は Summary を受ける）
//  refactor_groupFavorite.md Phase 4（onAppear の再 fetch はやめる。init で公開済み）
//

import Combine
import Foundation

@MainActor
final class FavoriteGroupPresenter: ObservableObject, FavoriteGroupPresenterProtocol {
    @Published private(set) var viewData: FavoriteGroupViewData = .empty
    @Published var route: FavoriteGroupRoute?

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: FavoriteGroupInteractor
    private weak var output: (any FavoriteGroupModuleOutput)?

    init(interactor: FavoriteGroupInteractor, output: (any FavoriteGroupModuleOutput)?) {
        self.interactor = interactor
        self.output = output
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける（親 AttendeeListPresenter と同じ）
    nonisolated deinit {}

    /// 一覧は init で公開済み。後差し廃止後の再 fetch はしない。
    func onAppear() {}

    func didSelectGroup(id: FavoriteGroupID) {
        output?.favoriteGroupDidSelect(id: id)
    }

    func didDeleteGroups(at offsets: IndexSet) {
        let ids = offsets.compactMap { offset in
            viewData.rows.indices.contains(offset) ? viewData.rows[offset].id : nil
        }
        guard !ids.isEmpty else { return }

        do {
            try interactor.deleteFavorites(ids: ids)
            publishState()
        } catch let error as FavoriteSaveError {
            switch error {
            case .persistenceFailed(let message):
                route = .alert(.deleteFailed(message: message))
            default:
                break
            }
        } catch {
            route = .alert(.deleteFailed(message: error.localizedDescription))
        }
    }

    func didTapClose() {
        output?.favoriteGroupDidCancel()
    }

    func dismissRoute() {
        route = nil
    }

    private func publishState() {
        do {
            viewData = FavoriteGroupViewDataBuilder.build(groups: try interactor.allFavorites())
            if case .alert(.loadFailed) = route {
                route = nil
            }
        } catch let error as FavoriteSaveError {
            viewData = .empty
            switch error {
            case .persistenceFailed(let message):
                route = .alert(.loadFailed(message: message))
            default:
                break
            }
        } catch {
            viewData = .empty
            route = .alert(.loadFailed(message: error.localizedDescription))
        }
    }
}
