//
//  FavoriteGroupContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER モジュール）
//  refactor_favorite.md Phase 1（Presenter から attach を外す。Gateway は assemble 時注入）
//  refactor_favorite.md Phase 2 / Phase 3（ViewData / Route。Interactor 削除は ID 配列）
//  refactor_groupFavorite.md Phase 2（子 Interactor の throws は persistenceFailed に限定）
//  refactor_groupFavorite.md Phase 3（一覧は Summary。fetchAll は使わない）
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
}

// MARK: - Presenter -> Interactor

/// 子 Interactor の throws は `FavoriteSaveError.persistenceFailed` に限定する。
/// 保存上限・不正名・未検出は親 AttendeeList の責務。エラー型の分割はしない。
nonisolated protocol FavoriteGroupInteractorProtocol: AnyObject {
    func allFavorites() throws -> [FavoriteGroupSummary]
    func deleteFavorites(ids: [FavoriteGroupID]) throws
}

// MARK: - Presenter -> 親モジュール

protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}
