//
//  GroupFavorite.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/24.
//  永続化モデル（SwiftData）。画面モジュール名は FavoriteGroup。
//  Snapshot への変換は GroupFavoriteGateway が担う。
//

import Foundation
import SwiftData

@Model
final class GroupFavorite {
    @Attribute(.unique) var id: UUID
    var name: String
    var members: [String]
    var createdAt: Date

    init(name: String, members: [String]) {
        self.id = UUID()
        self.name = name
        self.members = members
        self.createdAt = Date()
    }
}
