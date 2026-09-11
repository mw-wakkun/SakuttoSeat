//
//  AttendeeListRoute.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2（ルーティング定義）
//

import Foundation

/// Presenter が単一の真実として保持する提示状態。
/// View の `@State` シート／アラート／destination をこれに集約する。
nonisolated enum AttendeeListRoute: Identifiable, Equatable, Hashable {
    case seatingChart
    case simpleShuffle
    case favoriteList
    case bulkAdd
    case saveFavoritePrompt
    case alert(AttendeeListAlert)

    var id: String {
        switch self {
        case .seatingChart:
            return "seatingChart"
        case .simpleShuffle:
            return "simpleShuffle"
        case .favoriteList:
            return "favoriteList"
        case .bulkAdd:
            return "bulkAdd"
        case .saveFavoritePrompt:
            return "saveFavoritePrompt"
        case .alert(let alert):
            return "alert-\(alert.id)"
        }
    }

    var presentsAsSheet: Bool {
        switch self {
        case .favoriteList, .bulkAdd:
            return true
        case .seatingChart, .simpleShuffle, .saveFavoritePrompt, .alert:
            return false
        }
    }

    var presentsAsNavigation: Bool {
        switch self {
        case .seatingChart, .simpleShuffle:
            return true
        default:
            return false
        }
    }

    var presentsAsAlert: Bool {
        switch self {
        case .saveFavoritePrompt, .alert:
            return true
        default:
            return false
        }
    }
}

nonisolated enum AttendeeListAlert: Equatable, Identifiable, Hashable {
    case confirmReset
    case favoriteLimitReached(currentCount: Int, limit: Int)
    case saveFailed(message: String)

    var id: String {
        switch self {
        case .confirmReset:
            return "confirmReset"
        case .favoriteLimitReached:
            return "favoriteLimitReached"
        case .saveFailed:
            return "saveFailed"
        }
    }
}
