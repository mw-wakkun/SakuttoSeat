//
//  SeatingChartInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import Foundation

protocol SeatingChartInteractorProtocol {
    func shuffleAndAssign(attendees: [String], to tables: [SeatingTable]) -> [SeatingTable]
}

class SeatingChartInteractor: SeatingChartInteractorProtocol {
    func shuffleAndAssign(attendees: [String], to tables: [SeatingTable]) -> [SeatingTable] {
        // 1. 現在の全テーブルから「固定されている人」とその「座席インデックス」を特定
        var updatedTables = tables
        var lockedMembers: [UUID: (member: SeatingMember, tableIndex: Int, seatIndex: Int)] = [:]
        var currentlyAssignedNames: Set<String> = []
        
        for (tIndex, table) in tables.enumerated() {
            for (sIndex, member) in table.assignedMembers.enumerated() {
                if member.isLocked {
                    lockedMembers[member.id] = (member, tIndex, sIndex)
                    currentlyAssignedNames.insert(member.name)
                }
            }
        }
        
        // 2. 固定されていないメンバー候補を抽出
        // 全参加者のうち、現在ロックされていない名前だけをシャッフル対象にする
        let movableNames = attendees.filter { !currentlyAssignedNames.contains($0) }.shuffled()
        var nameIndex = 0
        
        // 3. 各テーブルに再割り当て
        for tIndex in 0..<updatedTables.count {
            var newMembersForTable: [SeatingMember] = []
            let capacity = updatedTables[tIndex].capacity
            
            for sIndex in 0..<capacity {
                // もしこの位置にロックされた人がいたら、その人を配置
                if let locked = lockedMembers.values.first(where: { $0.tableIndex == tIndex && $0.seatIndex == sIndex }) {
                    newMembersForTable.append(locked.member)
                } else if nameIndex < movableNames.count {
                    // ロックされていない位置にはシャッフルされた人を配置
                    newMembersForTable.append(SeatingMember(name: movableNames[nameIndex], isLocked: false))
                    nameIndex += 1
                }
            }
            updatedTables[tIndex].assignedMembers = newMembersForTable
        }
        
        return updatedTables
    }
}
