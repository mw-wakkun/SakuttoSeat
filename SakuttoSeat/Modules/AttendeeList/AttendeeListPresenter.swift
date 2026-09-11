//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 2（ViewData / Route の導入）
//

import Combine
import SwiftUI

@MainActor
final class AttendeeListPresenter: ObservableObject, AttendeeListPresenterProtocol {
    @Published private(set) var viewData: AttendeeListViewData = .empty
    @Published var route: AttendeeListRoute?

    private let interactor: AttendeeListInteractor
    private let router: AttendeeListRouter
    /// Protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象基底で保持する。
    /// Phase 3 で Interactor へ移す。
    private var favoriteGateway: GroupFavoriteGatewayBase = GroupFavoriteGatewayBase()

    init(interactor: AttendeeListInteractor, router: AttendeeListRouter) {
        self.interactor = interactor
        self.router = router
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける
    nonisolated deinit {}

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
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
        switch favoriteSaveAvailability() {
        case .available:
            route = .saveFavoritePrompt
        case .limitReached(let currentCount, let limit):
            route = .alert(.favoriteLimitReached(currentCount: currentCount, limit: limit))
        }
    }

    func didConfirmSaveFavorite(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            route = nil
            return
        }

        let memberNames = interactor.allAttendees().map(\.name)
        let newFavorite = GroupFavorite(name: trimmedName, members: memberNames)
        do {
            try favoriteGateway.insert(newFavorite)
            print("お気に入りグループを保存しました: \(trimmedName), メンバー数: \(memberNames.count)")
            route = nil
            publishState()
        } catch {
            print("お気に入りグループの保存に失敗しました: \(error)")
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func didTapShowFavorites() {
        publishState()
        route = .favoriteList
    }

    func didSelectFavoriteGroup(id: FavoriteGroupID) {
        guard let snapshot = viewData.favoriteGroups.first(where: { $0.id == id }) else { return }

        _ = interactor.removeAll()
        for name in snapshot.memberNames {
            _ = interactor.add(name: name)
        }

        route = nil
        publishState()
    }

    func didDeleteFavoriteGroups(at offsets: IndexSet) {
        guard let currentList = try? favoriteGateway.fetchAll() else { return }
        do {
            try favoriteGateway.delete(atOffsets: offsets, in: currentList)
            publishState()
        } catch {
            print("お気に入りグループの削除に失敗しました: \(error)")
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

    private func favoriteSaveAvailability() -> FavoriteSaveAvailability {
        let currentCount = (try? favoriteGateway.fetchCount()) ?? 0
        if currentCount < FeatureLimit.freeFavoriteGroupCount {
            return .available
        }
        return .limitReached(currentCount: currentCount, limit: FeatureLimit.freeFavoriteGroupCount)
    }

    private func publishState() {
        viewData = AttendeeListViewDataBuilder.build(
            attendees: interactor.allAttendees(),
            favoriteGroups: favoriteSnapshots()
        )
    }

    private func favoriteSnapshots() -> [FavoriteGroupSnapshot] {
        let favorites = (try? favoriteGateway.fetchAll()) ?? []
        return favorites.map { favorite in
            FavoriteGroupSnapshot(
                id: favorite.id,
                name: favorite.name,
                memberNames: favorite.members,
                memberSummary: favorite.members.joined(separator: ", ")
            )
        }
    }
}
