//
//  SakuttoSeatTests.swift
//  SakuttoSeatTests
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import Testing
@testable import SakuttoSeat
import Foundation

// クラス全体をメインスレッドで動かすように指定
@MainActor
struct SakuttoSeatTests {

    @Test func 参加者の追加が正しく行われるか() async throws {
        let interactor = AttendeeListInteractor()
        _ = interactor.addAttendee(name: "田中")
        
        let attendees = interactor.fetchAttendees()
        #expect(attendees.count == 1)
        #expect(attendees.first?.name == "田中")
    }

    @Test func 空白の名前はトリミングされるか() async throws {
        let presenter = AttendeeListPresenter(
            interactor: AttendeeListInteractor(),
            router: AttendeeListRouter()
        )
        
        presenter.didTapAddButton(name: "  佐藤  ")
        #expect(presenter.attendees.first?.name == "佐藤")
    }
    
    @Test func シャッフルで並び順が変わるか() async throws {
        let interactor = AttendeeListInteractor()
        _ = interactor.addAttendee(name: "A")
        _ = interactor.addAttendee(name: "B")
        _ = interactor.addAttendee(name: "C")
        _ = interactor.addAttendee(name: "D")
        _ = interactor.addAttendee(name: "E")
        
        let original = interactor.fetchAttendees()
        _ = interactor.shuffleAttendees()
        let shuffled = interactor.fetchAttendees()
        
        #expect(original.count == shuffled.count)
        #expect(original != shuffled)
    }
}
