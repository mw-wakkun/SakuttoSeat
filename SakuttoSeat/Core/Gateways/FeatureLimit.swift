//
//  FeatureLimit.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（無料枠の単一定義）
//

import Foundation

/// `nonisolated`: Interactor（nonisolated）から上限値を参照するため。
nonisolated enum FeatureLimit {
    static let freeTemplateCount = 3
    static let freeFavoriteGroupCount = 3
    static let freeColumnCount = 2
}
