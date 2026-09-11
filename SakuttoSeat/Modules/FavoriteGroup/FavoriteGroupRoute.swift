//
//  FavoriteGroupRoute.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 2（提示状態。`alert` プロパティを route に集約）
//

import Foundation

/// Presenter が単一の真実として保持する提示状態。
nonisolated enum FavoriteGroupRoute: Identifiable, Equatable {
    case alert(FavoriteGroupAlert)

    var id: String {
        switch self {
        case .alert(let alert):
            return "alert-\(alert.id)"
        }
    }
}

nonisolated enum FavoriteGroupAlert: Equatable, Identifiable {
    case deleteFailed(message: String)
    case loadFailed(message: String)

    var id: String {
        switch self {
        case .deleteFailed:
            return "deleteFailed"
        case .loadFailed:
            return "loadFailed"
        }
    }
}
