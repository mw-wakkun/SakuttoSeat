//
//  SeatingChartInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import Foundation

final class SeatingChartInteractor: SeatingChartInteractorProtocol {
    private func assign(attendees: [Attendee], to tables: [SeatingTable], shuffle: Bool) -> [SeatingTable] {
        var updatedTables = tables
        var lockedMembers: [UUID: (member: SeatingMember, tableIndex: Int, seatIndex: Int)] = [:]
        var currentlyAssignedIDs: Set<UUID> = []

        for (tIndex, table) in tables.enumerated() {
            for (sIndex, member) in table.assignedMembers.enumerated() {
                if member.isLocked {
                    lockedMembers[member.id] = (member, tIndex, sIndex)
                    currentlyAssignedIDs.insert(member.id)
                }
            }
        }

        let movableAttendees = attendees.filter { !currentlyAssignedIDs.contains($0.id) }
        let orderedAttendees = shuffle ? movableAttendees.shuffled() : movableAttendees
        var nameIndex = 0

        for tIndex in 0..<updatedTables.count {
            var newMembersForTable: [SeatingMember] = []
            let capacity = updatedTables[tIndex].capacity

            for sIndex in 0..<capacity {
                if let locked = lockedMembers.values.first(where: { $0.tableIndex == tIndex && $0.seatIndex == sIndex }) {
                    newMembersForTable.append(locked.member)
                } else if nameIndex < orderedAttendees.count {
                    let attendee = orderedAttendees[nameIndex]
                    newMembersForTable.append(SeatingMember(id: attendee.id, name: attendee.name, isLocked: false))
                    nameIndex += 1
                }
            }
            updatedTables[tIndex].assignedMembers = newMembersForTable
        }
        return updatedTables
    }

    func shuffleAndAssign(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable] {
        assign(attendees: attendees, to: tables, shuffle: true)
    }

    func assignInRegistrationOrder(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable] {
        assign(attendees: attendees, to: tables, shuffle: false)
    }
}
