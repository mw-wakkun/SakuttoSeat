//
//  AttendeeListContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2 / Phase 3 / Phase 4 / Phase 5（層間境界の明示）
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
    func didTapShowFavorites()
    func didSelectFavoriteGroup(id: FavoriteGroupID)
    func didTapBulkAddEntry()
    func didTapSeatingChart()
    func didTapSimpleShuffle()
    func dismissRoute()

    /// View は SwiftData の `ModelContext` だけを渡し、Gateway の保持は Interactor に委譲する。
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> Interactor

nonisolated protocol AttendeeListInteractorProtocol: AnyObject {
    func allAttendees() -> [Attendee]
    func add(name: String) -> [Attendee]
    func add(fromText text: String) -> [Attendee]
    func replaceAll(names: [String]) -> [Attendee]
    func remove(atOffsets offsets: IndexSet) -> [Attendee]
    func removeAll() -> [Attendee]
    func shuffle() -> [Attendee]

    func favoriteSaveAvailability() -> FavoriteSaveAvailability
    func saveCurrentAsFavorite(named name: String) throws
    func allFavorites() -> [FavoriteGroupSnapshot]
    func deleteFavorites(at offsets: IndexSet) throws
    func loadFavorite(id: FavoriteGroupID) throws -> [Attendee]

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
    @MainActor func makeFavoriteGroupModule(
        favoriteGateway: GroupFavoriteGatewayBase,
        output: (any FavoriteGroupModuleOutput)?
    ) -> AnyView
    @MainActor func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView
}
