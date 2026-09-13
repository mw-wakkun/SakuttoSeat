//
//  SimpleShuffleRoute.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表 Cover のために Route を 1 本足す。シートは持たない）
//

import Foundation

/// Presenter が単一の真実として保持する提示状態。
enum SimpleShuffleRoute: Identifiable, Equatable {
    /// 発表モード。タップ時点の ViewData スナップショットを渡す。
    case presentation(id: UUID, snapshot: SimpleShuffleViewData)

    var id: String {
        switch self {
        case .presentation(let id, _):
            return "presentation-\(id.uuidString)"
        }
    }

    var presentsAsFullScreenCover: Bool {
        if case .presentation = self { return true }
        return false
    }
}
