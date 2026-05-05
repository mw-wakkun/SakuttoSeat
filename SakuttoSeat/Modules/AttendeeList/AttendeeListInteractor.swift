//
//  AttendeeListInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import Foundation
import SwiftUI

protocol AttendeeListInteractorProtocol {
    func fetchAttendees() -> [Attendee]
    func addAttendee(name: String) -> [Attendee]
    func shuffleAttendees() -> [Attendee]
    func removeAttendee(at offsets: IndexSet) -> [Attendee]
    func resetAttendees() -> [Attendee]
}

class AttendeeListInteractor: AttendeeListInteractorProtocol {
    private var attendees: [Attendee] = []
    
    func fetchAttendees() -> [Attendee] {
        return attendees
    }
    
    func addAttendee(name: String) -> [Attendee] {
        let newAttendee = Attendee(name: name)
        attendees.append(newAttendee)
        return attendees
    }
    
    func shuffleAttendees() -> [Attendee] {
        guard attendees.count > 1 else { return attendees }
        
        let previousList = attendees
        // 最大3回試行して、前回と異なる並び順になるようにする
        for _ in 0..<3 {
            attendees.shuffle()
            if attendees != previousList { break }
        }
        return attendees
    }
    
    func removeAttendee(at offsets: IndexSet) -> [Attendee] {
        attendees.remove(atOffsets: offsets)
        return attendees
    }
    
    func resetAttendees() -> [Attendee] {
        attendees.removeAll()
        return attendees
    }
}
