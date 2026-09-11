//
//  SimpleShuffleInteractor.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  シャッフルは集合不変・順序変更。番号は並び順の 1-based。
//

import Foundation

nonisolated final class SimpleShuffleInteractor: SimpleShuffleInteractorProtocol {
    private var seats: [NumberedSeat]

    init(attendees: [Attendee]) {
        seats = attendees.enumerated().map { index, attendee in
            NumberedSeat(id: attendee.id, name: attendee.name, number: index + 1)
        }
    }

    func allSeats() -> [NumberedSeat] {
        seats
    }

    func shuffle() -> [NumberedSeat] {
        seats.shuffle()
        renumber()
        return seats
    }

    private func renumber() {
        for index in seats.indices {
            seats[index].number = index + 1
        }
    }
}
