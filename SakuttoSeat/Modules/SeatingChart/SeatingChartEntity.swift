//
//  SeatingChartEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import Foundation

// 座席の相対位置（将来的な拡張用）
enum SeatPosition: Int, CaseIterable {
    case topLeft = 0
    case topRight = 1
    case bottomLeft = 2
    case bottomRight = 3
}

// 会場レイアウト（向き）の定義
enum TableOrientation: String, CaseIterable, Identifiable {
    case none = "設定なし"
    case north = "▲ ステージ側"
    case south = "▼ 入り口側"
    case east = "▶︎ 窓際"
    case west = "◀︎ 通路側"
    
    var id: String { self.rawValue }
}

// 参加者モデル
struct SeatingMember: Identifiable, Equatable {
    let id = UUID()
    let name: String
    var isLocked: Bool = false
}

// テーブルモデル（ここを修正！）
struct SeatingTable: Identifiable {
    let id = UUID()
    var name: String
    var capacity: Int // 定員
    var orientation: TableOrientation = .none // ← これを追加！
    var assignedMembers: [SeatingMember] = []
}
