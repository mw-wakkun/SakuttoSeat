//
//  SeatingChartInteractorTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 0（準備と回帰テスト）
//

import XCTest
@testable import SakuttoSeat

/// `SeatingChartInteractor` の「リファクタリング前の実際の挙動」を固定する回帰テスト。
///
/// ここに書かれた期待値は必ずしも理想の仕様ではなく、現状の実装がどう振る舞うかの記録です。
/// `_既知の課題` が付いたテストは是正対象の挙動を意図的に固定しているため、
/// Phase 3 / Phase 6 で挙動を変更する際はテスト側も同時に更新してください。
@MainActor
final class SeatingChartInteractorTests: XCTestCase {

    private var interactor: SeatingChartInteractor!

    override func setUp() {
        super.setUp()
        interactor = SeatingChartInteractor()
    }

    override func tearDown() {
        interactor = nil
        super.tearDown()
    }

    // MARK: - ヘルパー

    private func makeAttendees(_ names: [String]) -> [Attendee] {
        names.map { Attendee(name: $0) }
    }

    private func makeTable(
        capacity: Int,
        columnCount: Int = 2,
        members: [SeatingMember] = []
    ) -> SeatingTable {
        SeatingTable(
            name: "テーブル",
            capacity: capacity,
            columnCount: columnCount,
            layoutDirection: .none,
            layoutText: "",
            assignedMembers: members
        )
    }

    private func assignedNames(_ tables: [SeatingTable]) -> [[String]] {
        tables.map { $0.assignedMembers.map(\.name) }
    }

    private func assignedIDs(_ tables: [SeatingTable]) -> Set<UUID> {
        Set(tables.flatMap { $0.assignedMembers.map(\.id) })
    }

    // MARK: - 登録順の割り当て

    func test_登録順割り当て_定員内なら登録順のまま配置される() {
        let attendees = makeAttendees(["A", "B", "C"])
        let tables = [makeTable(capacity: 4)]

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B", "C"])
        // Attendee の id がそのまま SeatingMember の id として引き継がれる
        XCTAssertEqual(result[0].assignedMembers.map(\.id), attendees.map(\.id))
    }

    func test_登録順割り当て_複数テーブルへ定員ぶんずつ順に詰められる() {
        let attendees = makeAttendees(["A", "B", "C", "D", "E"])
        let tables = [makeTable(capacity: 2), makeTable(capacity: 2), makeTable(capacity: 2)]

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(assignedNames(result), [["A", "B"], ["C", "D"], ["E"]])
    }

    func test_登録順割り当て_参加者が0人なら全テーブルが空席になる() {
        let tables = [makeTable(capacity: 4), makeTable(capacity: 4)]

        let result = interactor.assignInRegistrationOrder(attendees: [], to: tables)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.assignedMembers.isEmpty })
    }

    func test_登録順割り当て_既存の未ロック席は破棄されて再構築される() {
        let attendees = makeAttendees(["A", "B"])
        // 逆順で配置済みの状態から、登録順へ戻ることを確認する
        let existing = [
            SeatingMember(id: attendees[1].id, name: "B"),
            SeatingMember(id: attendees[0].id, name: "A")
        ]
        let tables = [makeTable(capacity: 2, members: existing)]

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
    }

    func test_登録順割り当て_総座席数が参加者数より少ないとあふれた参加者は配置されない_既知の課題() {
        let attendees = makeAttendees(["A", "B", "C"])
        let tables = [makeTable(capacity: 2)]

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)

        // Interactor は座席を増やさないため C はどこにも配置されず消える。
        // 現状は呼び出し側（Presenter.ensureSufficientTables）が事前に座席を確保する前提。
        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertFalse(assignedIDs(result).contains(attendees[2].id))
    }

    // MARK: - シャッフル

    func test_シャッフル_座席数が足りていれば全参加者が保持される() {
        let attendees = makeAttendees((1...10).map { "参加者\($0)" })
        let tables = [makeTable(capacity: 4), makeTable(capacity: 4), makeTable(capacity: 4)]

        let result = interactor.shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertEqual(assignedIDs(result), Set(attendees.map(\.id)))
    }

    func test_シャッフル_ロック席は同じテーブルの同じ位置に維持される() {
        let attendees = makeAttendees(["A", "B", "C", "D"])
        let tables = [
            makeTable(capacity: 2, members: [
                SeatingMember(id: attendees[0].id, name: "A", isLocked: true),
                SeatingMember(id: attendees[1].id, name: "B")
            ]),
            makeTable(capacity: 2, members: [
                SeatingMember(id: attendees[2].id, name: "C"),
                SeatingMember(id: attendees[3].id, name: "D")
            ])
        ]

        // ランダム性があるため複数回試行して不変条件を確認する
        for _ in 0..<20 {
            let result = interactor.shuffleAndAssign(attendees: attendees, to: tables)

            XCTAssertEqual(result[0].assignedMembers.first?.name, "A")
            XCTAssertEqual(result[0].assignedMembers.first?.isLocked, true)
            XCTAssertEqual(assignedIDs(result), Set(attendees.map(\.id)))
        }
    }

    func test_シャッフル_全席ロック済みなら配置は変わらない() {
        let attendees = makeAttendees(["A", "B"])
        let tables = [makeTable(capacity: 2, members: [
            SeatingMember(id: attendees[0].id, name: "A", isLocked: true),
            SeatingMember(id: attendees[1].id, name: "B", isLocked: true)
        ])]

        let result = interactor.shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertTrue(result[0].assignedMembers.allSatisfy(\.isLocked))
    }

    func test_シャッフル_未ロック席のロック状態はfalseで再生成される() {
        let attendees = makeAttendees(["A", "B"])
        let tables = [makeTable(capacity: 2, members: [
            SeatingMember(id: attendees[0].id, name: "A", isLocked: false),
            SeatingMember(id: attendees[1].id, name: "B", isLocked: false)
        ])]

        let result = interactor.shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertTrue(result[0].assignedMembers.allSatisfy { $0.isLocked == false })
    }

    // MARK: - 既知の課題（Phase 3 / 6 で是正予定）

    func test_定員より後ろの座席がロックされていると参加者が消える_既知の課題() {
        let attendees = makeAttendees(["A", "B", "C", "D"])
        // 定員 4 のときに 4 番目（seatIndex 3）をロックしたあと、定員を 2 に縮めた状態を再現する
        var table = makeTable(capacity: 4, members: [
            SeatingMember(id: attendees[0].id, name: "A"),
            SeatingMember(id: attendees[1].id, name: "B"),
            SeatingMember(id: attendees[2].id, name: "C"),
            SeatingMember(id: attendees[3].id, name: "D", isLocked: true)
        ])
        table.capacity = 2

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: [table])

        // D はロック済みとして再配置対象（movableAttendees）から除外される一方、
        // seatIndex 3 は定員 2 の走査範囲外なので再配置もされず、座席表から消える。
        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertFalse(assignedIDs(result).contains(attendees[3].id))
    }

    func test_ロック席より前の座席が埋まらないと位置が前詰めされる_既知の課題() {
        let attendees = makeAttendees(["A"])
        // 参加者は 1 人だけだが、seatIndex 2 にロック席がある状態
        let tables = [makeTable(capacity: 4, members: [
            SeatingMember(id: UUID(), name: "空"),
            SeatingMember(id: UUID(), name: "空"),
            SeatingMember(id: attendees[0].id, name: "A", isLocked: true)
        ])]

        let result = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)

        // assignedMembers は append で構築されるため、前方の座席が埋まらない場合
        // ロック席の位置（index 2）は保持されず先頭へ繰り上がる。
        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A"])
    }
}
