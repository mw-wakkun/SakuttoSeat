//
//  SeatingLayoutTemplate.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/15.
//

import Foundation
import SwiftData

// レイアウト情報のみを保持するためのCodableな構造体
struct TableTemplate: Codable {
    var name: String
    var capacity: Int
    var columnCount: Int
    var orientation: TableOrientation
}

@Model
final class SeatingLayoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var tables: [TableTemplate]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, tables: [TableTemplate], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tables = tables
        self.createdAt = createdAt
    }
}
