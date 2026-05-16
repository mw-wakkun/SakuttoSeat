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
        // 前後の余計な空白や改行をカット
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空文字の場合は何もせず現在のリストを返す
        guard !trimmedName.isEmpty else { return attendees }
        
        var finalName = trimmedName
        var count = 2
        
        // 【自動リネームロジック】
        // 既存のリストに全く同じ名前が存在する限り、末尾の番号をインクリメントしながらループ
        while attendees.contains(where: { $0.name == finalName }) {
            finalName = "\(trimmedName)(\(count))"
            count += 1
        }
        
        // 最終的にユニークになった名前で登録
        let newAttendee = Attendee(name: finalName)
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
