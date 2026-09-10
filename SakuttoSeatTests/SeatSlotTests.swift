//
//  SeatSlotTests.swift
//  SakuttoSeatTests
//

import XCTest
@testable import SakuttoSeat

/// 座席の表示単位（`SeatSlot`）のテスト。
///
/// シャッフル時のアニメーションは「並び替え前後で座席の id が保たれていること」に
/// 依存している。id が作り直されると SwiftUI が移動ではなく削除＋挿入と判断し、
/// アニメーションが失われて一瞬で切り替わってしまう。
/// そのためここでは id の安定性を明示的に検証する。
@MainActor
final class SeatSlotTests: XCTestCase {

    private func makeAttendees(_ names: [String]) -> [Attendee] {
        names.map { Attendee(name: $0) }
    }

    private func makeTable(capacity: Int, members: [SeatingMember]) -> SeatingTable {
        SeatingTable(
            name: "テーブルA",
            capacity: capacity,
            columnCount: 2,
            layoutDirection: .none,
            layoutText: "",
            assignedMembers: members
        )
    }

    func test_在席は並び順のまま展開され定員に足りない分は空席で埋まる() {
        let attendees = makeAttendees(["A", "B"])
        let table = makeTable(capacity: 4, members: [
            SeatingMember(id: attendees[0].id, name: "A"),
            SeatingMember(id: attendees[1].id, name: "B")
        ])

        let slots = SeatSlot.slots(for: table)

        XCTAssertEqual(slots.count, 4)
        XCTAssertEqual(slots.map(\.isOccupied), [true, true, false, false])
        XCTAssertEqual(slots.compactMap { $0.member?.name }, ["A", "B"])
    }

    func test_在席スロットのidは参加者idと一致する() {
        let attendees = makeAttendees(["A"])
        let table = makeTable(capacity: 2, members: [
            SeatingMember(id: attendees[0].id, name: "A")
        ])

        let slots = SeatSlot.slots(for: table)

        XCTAssertEqual(slots[0].id, attendees[0].id.uuidString)
    }

    func test_空席スロットのidはテーブルごとに一意になる() {
        let tableA = makeTable(capacity: 2, members: [])
        let tableB = makeTable(capacity: 2, members: [])

        let idsA = SeatSlot.slots(for: tableA).map(\.id)
        let idsB = SeatSlot.slots(for: tableB).map(\.id)

        XCTAssertEqual(Set(idsA).count, 2)
        XCTAssertTrue(Set(idsA).isDisjoint(with: Set(idsB)))
    }

    /// アニメーションの前提条件。ここが崩れると「チカチカする」挙動に戻る。
    func test_シャッフル後も座席idの集合は変化しない() {
        let interactor = SeatingChartInteractor()
        let attendees = makeAttendees((1...8).map { "参加者\($0)" })
        let tables = [
            makeTable(capacity: 4, members: []),
            makeTable(capacity: 4, members: [])
        ]

        let before = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)
        let beforeIDs = Set(before.flatMap { SeatSlot.slots(for: $0).map(\.id) })

        // 並び順が変わっても id の集合は同一であること（= SwiftUI が移動として扱える）
        for _ in 0..<10 {
            let after = interactor.shuffleAndAssign(attendees: attendees, to: before)
            let afterIDs = Set(after.flatMap { SeatSlot.slots(for: $0).map(\.id) })

            XCTAssertEqual(afterIDs, beforeIDs)
        }
    }

    func test_同じテーブルを再展開してもidは同一になる() {
        let attendees = makeAttendees(["A", "B"])
        let table = makeTable(capacity: 4, members: [
            SeatingMember(id: attendees[0].id, name: "A"),
            SeatingMember(id: attendees[1].id, name: "B")
        ])

        XCTAssertEqual(SeatSlot.slots(for: table).map(\.id), SeatSlot.slots(for: table).map(\.id))
    }
}
