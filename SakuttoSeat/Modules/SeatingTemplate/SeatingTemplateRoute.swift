//
//  SeatingTemplateRoute.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（提示状態。失敗は子の `route = .alert`）
//

import Foundation

/// Presenter が単一の真実として保持する提示状態。
nonisolated enum SeatingTemplateRoute: Identifiable, Equatable {
    case alert(SeatingTemplateAlert)

    var id: String {
        switch self {
        case .alert(let alert):
            return "alert-\(alert.id)"
        }
    }
}

nonisolated enum SeatingTemplateAlert: Equatable, Identifiable {
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
