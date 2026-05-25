//
//  GroupFavorite.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/24.
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
