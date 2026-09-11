//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3 / Phase 4
//  永続化は Interactor。遷移先の組み立ては Router へ委譲。
//

import Combine
import SwiftUI

@MainActor
final class AttendeeListPresenter: ObservableObject, AttendeeListPresenterProtocol {
    @Published private(set) var viewData: AttendeeListViewData = .empty
    @Published var route: AttendeeListRoute?

    private let interactor: AttendeeListInteractor
    private let router: AttendeeListRouter

    init(interactor: AttendeeListInteractor, router: AttendeeListRouter) {
        self.interactor = interactor
        self.router = router
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける
    nonisolated deinit {}

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        interactor.attachFavoriteGateway(gateway)
        publishState()
    }

    func onAppear() {
        publishState()
    }

    func didTapAdd(name: String) {
        _ = interactor.add(name: name)
        publishState()
    }

    func didTapBulkAdd(text: String) {
        _ = interactor.add(fromText: text)
        route = nil
        publishState()
    }

    func didDeleteAttendees(at offsets: IndexSet) {
        _ = interactor.remove(atOffsets: offsets)
        publishState()
    }

    func didTapReset() {
        route = .alert(.confirmReset)
    }

    func didConfirmReset() {
        _ = interactor.removeAll()
        route = nil
        publishState()
    }

    func didTapSaveFavorite() {
        switch interactor.favoriteSaveAvailability() {
        case .available:
            route = .saveFavoritePrompt
        case .limitReached(let currentCount, let limit):
            route = .alert(.favoriteLimitReached(currentCount: currentCount, limit: limit))
        }
    }

    func didConfirmSaveFavorite(name: String) {
        do {
            try interactor.saveCurrentAsFavorite(named: name)
            route = nil
            publishState()
        } catch let error as FavoriteSaveError {
            switch error {
            case .limitReached(let currentCount, let limit):
                route = .alert(.favoriteLimitReached(currentCount: currentCount, limit: limit))
            case .invalidName, .notFound:
                route = nil
            case .persistenceFailed(let message):
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didTapShowFavorites() {
        publishState()
        route = .favoriteList
    }

    func didSelectFavoriteGroup(id: FavoriteGroupID) {
        do {
            _ = try interactor.loadFavorite(id: id)
            route = nil
            publishState()
        } catch FavoriteSaveError.notFound {
            return
        } catch let error as FavoriteSaveError {
            if case .persistenceFailed(let message) = error {
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didDeleteFavoriteGroups(at offsets: IndexSet) {
        do {
            try interactor.deleteFavorites(at: offsets)
            publishState()
        } catch let error as FavoriteSaveError {
            if case .persistenceFailed(let message) = error {
                route = .alert(.saveFailed(message: message))
            }
        } catch {
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didTapBulkAddEntry() {
        route = .bulkAdd
    }

    func didTapSeatingChart() {
        route = .seatingChart
    }

    func didTapSimpleShuffle() {
        route = .simpleShuffle
    }

    func dismissRoute() {
        route = nil
    }

    /// ナビゲーション先を Router 経由で組み立てる（View から子モジュール型名を排除）
    func makeRouteView(_ route: AttendeeListRoute) -> AnyView {
        switch route {
        case .seatingChart:
            return router.makeSeatingChartModule(attendees: interactor.allAttendees())
        case .simpleShuffle:
            return router.makeSimpleShuffleModule(attendees: interactor.allAttendees())
        case .favoriteList, .bulkAdd, .saveFavoritePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    /// シート内容を Router 経由で組み立てる（SeatingChart の `makeRouteSheet` と同じ形）
    func makeRouteSheet(_ route: AttendeeListRoute) -> AnyView {
        switch route {
        case .favoriteList:
            return router.makeFavoriteGroupModule(
                groups: viewData.favoriteGroups,
                output: self
            )
        case .bulkAdd:
            return router.makeBulkAddModule(output: self)
        case .seatingChart, .simpleShuffle, .saveFavoritePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    // MARK: - Private

    private func publishState() {
        viewData = AttendeeListViewDataBuilder.build(
            attendees: interactor.allAttendees(),
            favoriteGroups: interactor.allFavorites()
        )
    }
}

// MARK: - 子モジュール Output

extension AttendeeListPresenter: FavoriteGroupModuleOutput {
    func favoriteGroupDidSelect(id: FavoriteGroupID) {
        didSelectFavoriteGroup(id: id)
    }

    func favoriteGroupDidDelete(at offsets: IndexSet) {
        didDeleteFavoriteGroups(at: offsets)
    }

    func favoriteGroupDidCancel() {
        dismissRoute()
    }
}

extension AttendeeListPresenter: BulkAddModuleOutput {
    func bulkAddDidConfirm(text: String) {
        didTapBulkAdd(text: text)
    }

    func bulkAddDidCancel() {
        dismissRoute()
    }
}
