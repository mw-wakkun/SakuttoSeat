//
//  FavoriteGroupInteractor.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  一覧の取得・削除は子 Interactor が Gateway を持つ（保存・読込置換は親）。
//  refactor_favorite.md Phase 3（削除は ID 配列。@Model は Gateway 内に閉じる）
//

import Foundation

nonisolated final class FavoriteGroupInteractor: FavoriteGroupInteractorProtocol {
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var favoriteGateway: GroupFavoriteGatewayBase

    init(favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()) {
        self.favoriteGateway = favoriteGateway
    }

    /// テスト用の差し替え。本番は assemble 時に注入済み。
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
    }

    func allFavorites() throws -> [FavoriteGroupSnapshot] {
        do {
            return try favoriteGateway.fetchAll()
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func deleteFavorites(ids: [FavoriteGroupID]) throws {
        do {
            try favoriteGateway.delete(ids: ids)
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }
}
