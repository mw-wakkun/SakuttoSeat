//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3 / Phase 4 / Phase 5
//  永続化は Interactor。遷移先の組み立ては Router へ委譲。
//  お気に入り一覧・一括追加は子モジュール。選択／確定は Output で受ける。
//  refactor_favorite.md Phase 3（シート組み立ては gatewayHolder。Presenter は Gateway 型を渡さない）
//  refactor_favorite.md Phase 4（`.favoriteList` 期間中は子 Presenter を 1 度だけ保持）
//

import Combine
import SwiftUI

@MainActor
final class AttendeeListPresenter: ObservableObject, AttendeeListPresenterProtocol {
    @Published private(set) var viewData: AttendeeListViewData = .empty
    @Published var route: AttendeeListRoute?

    private let interactor: AttendeeListInteractor
    private let router: AttendeeListRouter

    /// `.favoriteList` 期間中だけ保持する。
    /// `.sheet(item:)` の content 再評価で再 assemble すると子の alert / 編集中状態が消えるため。
    /// `didTapShowFavorites` のたびに新規 assemble、閉じたら破棄（Gateway 差し替え後の stale を防ぐ）。
    private(set) var favoriteGroupPresenter: FavoriteGroupPresenter?

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
        setRoute(nil)
        publishState()
    }

    func didDeleteAttendees(at offsets: IndexSet) {
        _ = interactor.remove(atOffsets: offsets)
        publishState()
    }

    func didTapReset() {
        setRoute(.alert(.confirmReset))
    }

    func didConfirmReset() {
        _ = interactor.removeAll()
        setRoute(nil)
        publishState()
    }

    func didTapSaveFavorite() {
        switch interactor.favoriteSaveAvailability() {
        case .available:
            setRoute(.saveFavoritePrompt)
        case .limitReached(let currentCount, let limit):
            setRoute(.alert(.favoriteLimitReached(currentCount: currentCount, limit: limit)))
        }
    }

    func didConfirmSaveFavorite(name: String) {
        do {
            try interactor.saveCurrentAsFavorite(named: name)
            setRoute(nil)
            publishState()
        } catch let error as FavoriteSaveError {
            switch error {
            case .limitReached(let currentCount, let limit):
                setRoute(.alert(.favoriteLimitReached(currentCount: currentCount, limit: limit)))
            case .invalidName, .notFound:
                setRoute(nil)
            case .persistenceFailed(let message):
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }

    func didTapShowFavorites() {
        favoriteGroupPresenter = router.makeFavoriteGroupPresenter(
            gatewayHolder: interactor,
            output: self
        )
        setRoute(.favoriteList)
    }

    func didSelectFavoriteGroup(id: FavoriteGroupID) {
        do {
            _ = try interactor.loadFavorite(id: id)
            setRoute(nil)
            publishState()
        } catch FavoriteSaveError.notFound {
            return
        } catch let error as FavoriteSaveError {
            if case .persistenceFailed(let message) = error {
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }

    func didTapBulkAddEntry() {
        setRoute(.bulkAdd)
    }

    func didTapSeatingChart() {
        setRoute(.seatingChart)
    }

    func didTapSimpleShuffle() {
        setRoute(.simpleShuffle)
    }

    func dismissRoute() {
        setRoute(nil)
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
            return router.makeFavoriteGroupSheet(presenter: favoriteGroupSheetPresenter())
        case .bulkAdd:
            return router.makeBulkAddModule(output: self)
        case .seatingChart, .simpleShuffle, .saveFavoritePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    // MARK: - Private

    private func publishState() {
        viewData = AttendeeListViewDataBuilder.build(attendees: interactor.allAttendees())
    }

    /// `didTapShowFavorites` で assemble 済みならそれを返す。未セットならここで 1 度だけ作る。
    private func favoriteGroupSheetPresenter() -> FavoriteGroupPresenter {
        if let favoriteGroupPresenter {
            return favoriteGroupPresenter
        }
        let assembled = router.makeFavoriteGroupPresenter(
            gatewayHolder: interactor,
            output: self
        )
        favoriteGroupPresenter = assembled
        return assembled
    }

    /// `.favoriteList` 以外へ移るときは子 Presenter を破棄する。
    private func setRoute(_ newRoute: AttendeeListRoute?) {
        if newRoute != .favoriteList {
            favoriteGroupPresenter = nil
        }
        route = newRoute
    }
}

// MARK: - 子モジュール Output

extension AttendeeListPresenter: FavoriteGroupModuleOutput {
    func favoriteGroupDidSelect(id: FavoriteGroupID) {
        didSelectFavoriteGroup(id: id)
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
