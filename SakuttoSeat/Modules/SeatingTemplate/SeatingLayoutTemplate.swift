//
//  SeatingLayoutTemplate.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/15.
//  永続化モデル（SwiftData）。画面モジュール名は SeatingTemplate。
//  画面型は `SeatingTemplate*`（子 VIPER は Phase 2）。型名のリネームは本計画では行わない。
//

import Foundation
import SwiftData

// レイアウト情報のみを保持するためのCodableな構造体
// 注意: 方向（layoutDirection）と表示テキスト（layoutText）を分離
//
// `nonisolated`: 既定の MainActor 隔離だと明示 init を
// `nonisolated` な Interactor から呼べないため。
nonisolated struct TableTemplate: Codable {
    var name: String
    var capacity: Int
    var columnCount: Int
    var layoutDirection: LayoutDirection
    var layoutText: String

    // カスタムデコードを行い、以前のバージョンで使っていた
    // `orientation` フィールド（TableOrientation）を受け取れるようにします。
    private enum CodingKeys: String, CodingKey {
        case name, capacity, columnCount, layoutDirection, layoutText, orientation
    }

    // 旧仕様の列挙子に合わせた一時的な型を用意してデコードする
    private enum OldOrientation: String, Codable {
        case none = "設定なし"
        case north = "▲ ステージ側"
        case south = "▼ 入り口側"
        case east = "▶︎ 窓際"
        case west = "◀︎ 通路側"
    }

    init(name: String, capacity: Int, columnCount: Int, layoutDirection: LayoutDirection, layoutText: String) {
        self.name = name
        self.capacity = capacity
        self.columnCount = columnCount
        self.layoutDirection = layoutDirection
        self.layoutText = layoutText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.capacity = try container.decode(Int.self, forKey: .capacity)
        self.columnCount = try container.decode(Int.self, forKey: .columnCount)

        // 新フィールドがあればそれを優先
        if let dir = try? container.decode(LayoutDirection.self, forKey: .layoutDirection) {
            self.layoutDirection = dir
            self.layoutText = (try? container.decode(String.self, forKey: .layoutText)) ?? ""
            return
        }

        // 旧フィールド 'orientation' が残っている可能性があるためフェールバック
        if let old = try? container.decode(OldOrientation.self, forKey: .orientation) {
            switch old {
            case .none:
                self.layoutDirection = .none
                self.layoutText = ""
            case .north:
                self.layoutDirection = .top
                self.layoutText = "ステージ側"
            case .south:
                self.layoutDirection = .bottom
                self.layoutText = "入り口側"
            case .east:
                self.layoutDirection = .right
                self.layoutText = "窓際"
            case .west:
                self.layoutDirection = .left
                self.layoutText = "通路側"
            }
            return
        }

        // どちらのキーもない場合はデフォルト
        self.layoutDirection = .none
        self.layoutText = ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(columnCount, forKey: .columnCount)
        try container.encode(layoutDirection, forKey: .layoutDirection)
        try container.encode(layoutText, forKey: .layoutText)
    }
}

@Model
final class SeatingLayoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var tables: [TableTemplate]
    var globalColumnCount: Int = 2  // デフォルト値を設定して既存データとの互換性を確保
    var createdAt: Date

    init(id: UUID = UUID(), name: String, tables: [TableTemplate], globalColumnCount: Int = 2, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tables = tables
        self.globalColumnCount = globalColumnCount
        self.createdAt = createdAt
    }
}
