//
//  AttendeeListContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2 / Phase 3 / Phase 4 / Phase 5（層間境界の明示）
//  refactor_favorite.md Phase 3（親 Interactor から一覧・削除を外す。子組み立ては gatewayHolder）
//  refactor_favorite.md Phase 4（お気に入りシートは Presenter 組み立てと View ラップを分離）
//  refactor_groupFavorite.md Phase 4（PresenterProtocol から attachFavoriteGateway を外す）
//  refactor_groupFavorite.md Phase 5（結合 makeFavoriteGroupModule は削除）
//

import SwiftUI

// MARK: - View <- Presenter

/// View は Presenter の公開状態（ViewData / Route）のみを読む。Entity は現れない。
///
/// `ObservableObject` は具象 Presenter 側で準拠する。
/// Protocol に載せると MainActor 隔離下の deinit で解放不整合が起きやすいため分離する。
@MainActor
protocol AttendeeListPresenterProtocol: AnyObject {
    var viewData: AttendeeListViewData { get }
    var route: AttendeeListRoute? { get set }

    func onAppear()
    func didTapAdd(name: String)
    func didTapBulkAdd(text: String)
    func didDeleteAttendees(at offsets: IndexSet)
    func didTapReset()
    func didConfirmReset()
    func didTapSaveFavorite()
    func didConfirmSaveFavorite(name: String)
    func didConfirmWatchAd()
    func didCancelFavoriteLimit()
    func didTapShowFavorites()
    func didTapBulkAddEntry()
    func didTapSeatingChart()
    func didTapSimpleShuffle()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol AttendeeListInteractorProtocol: AnyObject {
    func allAttendees() -> [Attendee]
    func add(name: String) -> [Attendee]
    func add(fromText text: String) -> [Attendee]
    func replaceAll(names: [String]) -> [Attendee]
    func remove(atOffsets offsets: IndexSet) -> [Attendee]
    func removeAll() -> [Attendee]

    func favoriteSaveAvailability() -> FavoriteSaveAvailability
    func grantOneTimeFavoriteSaveBypass()
    func revokeOneTimeFavoriteSaveBypass()
    func saveCurrentAsFavorite(named name: String) throws
    func loadFavorite(id: FavoriteGroupID) throws -> [Attendee]

    /// テスト用の差し替え。本番は assemble 時に注入済み。View / PresenterProtocol からは呼ばない。
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
/// 各メソッドに @MainActor を付与する。
///
/// `AnyView` は Router 境界に限定する。モジュール内の描画分岐では使わない。
protocol AttendeeListRouterProtocol: AnyObject {
    @MainActor func makeSeatingChartModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeSimpleShuffleModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeFavoriteGroupPresenter(
        gatewayHolder: AttendeeListInteractor,
        output: (any FavoriteGroupModuleOutput)?
    ) -> FavoriteGroupPresenter
    @MainActor func makeFavoriteGroupSheet(presenter: FavoriteGroupPresenter) -> AnyView
    @MainActor func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView
    @MainActor func waitUntilPresentable() async
    @MainActor func presentRewardedAd() async throws
}
