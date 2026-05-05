//
//  AttendeeListEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import Foundation

struct Attendee: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
