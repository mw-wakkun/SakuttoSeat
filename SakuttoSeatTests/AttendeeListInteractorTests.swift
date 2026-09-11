//
//  AttendeeListInteractorTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0（現状の挙動を固定する回帰テスト）
//

import XCTest
@testable import SakuttoSeat

final class AttendeeListInteractorTests: XCTestCase {

    private func names(of attendees: [Attendee]) -> [String] {
        attendees.map(\.name)
    }

    // MARK: - 追加

    func test_名前を1人追加できる() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(name: "田中")

        XCTAssertEqual(names(of: attendees), ["田中"])
        XCTAssertEqual(names(of: interactor.allAttendees()), ["田中"])
    }

    func test_前後の空白と改行を除去して追加する() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(name: "  佐藤  \n")

        XCTAssertEqual(names(of: attendees), ["佐藤"])
    }

    func test_空文字や空白のみは追加しない() {
        let interactor = AttendeeListInteractor()

        XCTAssertTrue(interactor.add(name: "").isEmpty)
        XCTAssertTrue(interactor.add(name: "   ").isEmpty)
        XCTAssertTrue(interactor.add(name: "\n\t").isEmpty)
        XCTAssertTrue(interactor.allAttendees().isEmpty)
    }

    func test_同名は連番を付けてユニークにする() {
        let interactor = AttendeeListInteractor()

        _ = interactor.add(name: "田中")
        _ = interactor.add(name: "田中")
        let attendees = interactor.add(name: "田中")

        XCTAssertEqual(names(of: attendees), ["田中", "田中(2)", "田中(3)"])
    }

    // MARK: - 一括追加

    func test_改行と半角全角カンマで分割し空要素をスキップする() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(fromText: "太郎\n  花子  ,次郎、\n、 四郎")

        XCTAssertEqual(names(of: attendees), ["太郎", "花子", "次郎", "四郎"])
    }

    func test_一括追加でも同名はユニーク化する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(name: "A")

        let attendees = interactor.add(fromText: "A,B")

        XCTAssertEqual(names(of: attendees), ["A", "A(2)", "B"])
    }

    // MARK: - 削除

    func test_単一のインデックスを削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C")

        let attendees = interactor.remove(atOffsets: IndexSet(integer: 1))

        XCTAssertEqual(names(of: attendees), ["A", "C"])
    }

    func test_複数のインデックスを一度に削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C,D")

        let attendees = interactor.remove(atOffsets: IndexSet([0, 2]))

        XCTAssertEqual(names(of: attendees), ["B", "D"])
    }

    func test_全員を削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B")

        let attendees = interactor.removeAll()

        XCTAssertTrue(attendees.isEmpty)
        XCTAssertTrue(interactor.allAttendees().isEmpty)
    }

    // MARK: - シャッフル

    func test_シャッフルしても要素の集合と件数は変わらない() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C,D,E")
        let original = interactor.allAttendees()

        let shuffled = interactor.shuffle()

        XCTAssertEqual(shuffled.count, original.count)
        XCTAssertEqual(Set(names(of: shuffled)), Set(names(of: original)))
        XCTAssertEqual(names(of: interactor.allAttendees()), names(of: shuffled))
    }

    func test_1人以下ではシャッフルしても順序は変わらない() {
        let empty = AttendeeListInteractor()
        XCTAssertTrue(empty.shuffle().isEmpty)

        let single = AttendeeListInteractor()
        _ = single.add(name: "A")
        XCTAssertEqual(names(of: single.shuffle()), ["A"])
    }
}
