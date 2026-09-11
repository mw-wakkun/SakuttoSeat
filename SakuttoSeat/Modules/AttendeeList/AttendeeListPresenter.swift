//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3（永続化は Interactor。ViewData 更新は publishState のみ）
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

    // MARK: - ナビゲーション（Phase 4 で Router へ委譲）

    func view(for route: AttendeeListRoute) -> AnyView {
        switch route {
        case .seatingChart:
            return router.makeSeatingChartView(attendees: interactor.allAttendees())
        case .simpleShuffle:
            return router.makeSimpleShuffleView(attendees: interactor.allAttendees().map(\.name))
        case .favoriteList, .bulkAdd, .saveFavoritePrompt, .alert:
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
