//
//  SeatingChartEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import Foundation

// テーブルの向き（方向）を表す列挙型。
// 表示用のテキストは別プロパティ（layoutText）で扱うため、
// この列挙型は「方向」だけを表現します。
enum LayoutDirection: String, CaseIterable, Identifiable, Codable {
    case none = "指定なし"
    case top = "上"
    case bottom = "下"
    case left = "左"
    case right = "右"

    var id: String { self.rawValue }
}

// 参加者モデル
struct SeatingMember: Identifiable, Equatable {
    let id: UUID
    let name: String
    var isLocked: Bool = false
}

// テーブルモデル
struct SeatingTable: Identifiable {
    let id = UUID()
    var name: String
    var capacity: Int // 定員
    var columnCount: Int = 2 // ★ 横の列数（デフォルト2列）
    // 方向と表示テキストを分離
    var layoutDirection: LayoutDirection = .none
    var layoutText: String = ""
    var assignedMembers: [SeatingMember] = []
}
