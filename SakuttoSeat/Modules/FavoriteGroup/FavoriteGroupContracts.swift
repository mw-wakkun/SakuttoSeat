//
//  FavoriteGroupContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER モジュール）
//  refactor_favorite.md Phase 2 / Phase 3（ViewData / Route。Interactor 削除は ID 配列）
//

import Foundation

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol FavoriteGroupPresenterProtocol: AnyObject {
    var viewData: FavoriteGroupViewData { get }
    var route: FavoriteGroupRoute? { get set }

    func onAppear()
    func didSelectGroup(id: FavoriteGroupID)
    func didDeleteGroups(at offsets: IndexSet)
    func didTapClose()
    func dismissRoute()
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> Interactor

nonisolated protocol FavoriteGroupInteractorProtocol: AnyObject {
    func allFavorites() throws -> [FavoriteGroupSnapshot]
    func deleteFavorites(ids: [FavoriteGroupID]) throws
}

// MARK: - Presenter -> 親モジュール

protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}
