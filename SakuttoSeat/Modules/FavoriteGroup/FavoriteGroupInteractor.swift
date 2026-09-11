//
//  FavoriteGroupInteractor.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  一覧の取得・削除は子 Interactor が Gateway を持つ（保存・読込置換は親）。
//  refactor_favorite.md Phase 2（allFavorites は throws。失敗は Presenter が route にする）
//

import Foundation

nonisolated final class FavoriteGroupInteractor: FavoriteGroupInteractorProtocol {
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var favoriteGateway: GroupFavoriteGatewayBase

    init(favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()) {
        self.favoriteGateway = favoriteGateway
    }

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
    }

    func allFavorites() throws -> [FavoriteGroupSnapshot] {
        do {
            return try favoriteGateway.fetchAll().map { $0.makeSnapshot() }
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func deleteFavorites(at offsets: IndexSet) throws {
        let currentList: [GroupFavorite]
        do {
            currentList = try favoriteGateway.fetchAll()
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }

        do {
            try favoriteGateway.delete(atOffsets: offsets, in: currentList)
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }
}
