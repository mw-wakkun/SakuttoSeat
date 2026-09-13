//
//  FeatureLimit.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（無料枠の単一定義）
//  v2.1（人数・会場サイズの無料／絶対上限。View にマジックナンバーを書かない）
//

import Foundation

/// `nonisolated`: Interactor（nonisolated）から上限値を参照するため。
nonisolated enum FeatureLimit {
    static let freeTemplateCount = 3
    static let freeFavoriteGroupCount = 3

    static let freeColumnCount = 2
    static let maxColumnCount = 10

    static let freeRowCount = 5
    static let maxRowCount = 10

    static let freeTableCount = 10
    static let maxTableCount = 40

    static let freeAttendeeCount = 40
    static let maxAttendeeCount = 120

    /// 描画セル数の内部キャップ。ユーザー向け文言には出さない。
    static let maxTotalSeatCount = 160
}
