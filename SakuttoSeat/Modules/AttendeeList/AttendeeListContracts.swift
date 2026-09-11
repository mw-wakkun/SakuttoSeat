//
//  AttendeeListContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2（層間境界の明示）
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
    func didDeleteFavoriteGroups(at offsets: IndexSet)
    func didTapBulkAddEntry()
    func didTapSeatingChart()
    func didTapSimpleShuffle()
    func dismissRoute()

    /// Phase 3 で Interactor へ移す。過渡期は Presenter が Gateway を保持する。
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> Interactor

/// Phase 3 でお気に入り永続化・一括置換・上限判定をここに追加する。
nonisolated protocol AttendeeListInteractorProtocol: AnyObject {
    func allAttendees() -> [Attendee]
    func add(name: String) -> [Attendee]
    func add(fromText text: String) -> [Attendee]
    func remove(atOffsets offsets: IndexSet) -> [Attendee]
    func removeAll() -> [Attendee]
    func shuffle() -> [Attendee]
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
/// 各メソッドに @MainActor を付与する。
///
/// Phase 4 で Router が準拠する。Phase 2 では Presenter.view(for:) が暫定的に遷移先を返す。
protocol AttendeeListRouterProtocol: AnyObject {
    @MainActor func makeSeatingChartModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeSimpleShuffleModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeFavoriteGroupModule(output: (any FavoriteGroupModuleOutput)?) -> AnyView
    @MainActor func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView
}

// MARK: - 子モジュール Output
//
// Phase 5 で FavoriteGroup / BulkAdd を切り出すときに結線する。

protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}

protocol BulkAddModuleOutput: AnyObject {
    func bulkAddDidConfirm(text: String)
    func bulkAddDidCancel()
}
