//
//  SimpleShuffleTests.swift
//  SakuttoSeatTests
//
//  refactor_simple.md Phase 0（番号札の現状挙動を固定する回帰）
//
//  `_既知の課題` が付いたテストは是正対象の挙動を意図的に固定している。
//  初期表示の登録順は Phase 4、Share / Snapshot の `[String]` 依存は Phase 2 で更新する。
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class SimpleShuffleInteractorTests: XCTestCase {

    func test_初期状態は登録順で番号は1始まり_IDを維持する_QA9_1と不一致_既知の課題() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子"), Attendee(name: "次郎")]
        let interactor = SimpleShuffleInteractor(attendees: attendees)

        let seats = interactor.allSeats()

        XCTAssertEqual(seats.map(\.id), attendees.map(\.id))
        XCTAssertEqual(seats.map(\.name), ["太郎", "花子", "次郎"])
        XCTAssertEqual(seats.map(\.number), [1, 2, 3])
    }

    func test_シャッフルしてもIDと名前の集合は変わらない() {
        let attendees = [
            Attendee(name: "A"),
            Attendee(name: "B"),
            Attendee(name: "C"),
            Attendee(name: "D"),
            Attendee(name: "E")
        ]
        let interactor = SimpleShuffleInteractor(attendees: attendees)
        let originalIDs = Set(attendees.map(\.id))
        let originalNames = Set(attendees.map(\.name))

        let shuffled = interactor.shuffle()

        XCTAssertEqual(shuffled.count, attendees.count)
        XCTAssertEqual(Set(shuffled.map(\.id)), originalIDs)
        XCTAssertEqual(Set(shuffled.map(\.name)), originalNames)
        XCTAssertEqual(shuffled.map(\.number), [1, 2, 3, 4, 5])
        XCTAssertEqual(interactor.allSeats().map(\.id), shuffled.map(\.id))
        XCTAssertEqual(interactor.allSeats().map(\.name), shuffled.map(\.name))
        XCTAssertEqual(interactor.allSeats().map(\.number), shuffled.map(\.number))
    }

    func test_同名でもIDは一意のまま残る() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "太郎")]
        let interactor = SimpleShuffleInteractor(attendees: attendees)

        let shuffled = interactor.shuffle()

        XCTAssertEqual(Set(shuffled.map(\.id)), Set(attendees.map(\.id)))
        XCTAssertEqual(shuffled.map(\.name), ["太郎", "太郎"])
        XCTAssertEqual(Set(shuffled.map(\.id)).count, 2)
    }

    func test_1人以下では順序も番号も変わらない() {
        let empty = SimpleShuffleInteractor(attendees: [])
        XCTAssertTrue(empty.shuffle().isEmpty)

        let attendee = Attendee(name: "A")
        let single = SimpleShuffleInteractor(attendees: [attendee])
        let shuffled = single.shuffle()

        XCTAssertEqual(shuffled.map(\.id), [attendee.id])
        XCTAssertEqual(shuffled.map(\.name), ["A"])
        XCTAssertEqual(shuffled.map(\.number), [1])
    }
}

// MARK: - ViewData

final class SimpleShuffleViewDataTests: XCTestCase {

    func test_行は座席のidと番号をそのまま載せる() {
        let seats = [
            NumberedSeat(id: UUID(), name: "A", number: 1),
            NumberedSeat(id: UUID(), name: "B", number: 2)
        ]

        let viewData = SimpleShuffleViewDataBuilder.build(seats: seats)

        XCTAssertEqual(viewData.rows.map(\.id), seats.map(\.id))
        XCTAssertEqual(viewData.rows.map(\.number), [1, 2])
        XCTAssertEqual(viewData.rows.map(\.name), ["A", "B"])
    }

    func test_番号はindexではなくseatのnumberを載せる() {
        let firstID = UUID()
        let secondID = UUID()
        let seats = [
            NumberedSeat(id: firstID, name: "A", number: 10),
            NumberedSeat(id: secondID, name: "B", number: 3)
        ]

        let viewData = SimpleShuffleViewDataBuilder.build(seats: seats)

        XCTAssertEqual(viewData.rows.map(\.id), [firstID, secondID])
        XCTAssertEqual(viewData.rows.map(\.number), [10, 3])
        XCTAssertEqual(viewData.rows.map(\.name), ["A", "B"])
    }

    func test_空配列はemptyと同じ行になる() {
        let viewData = SimpleShuffleViewDataBuilder.build(seats: [])

        XCTAssertEqual(viewData, .empty)
        XCTAssertTrue(viewData.rows.isEmpty)
    }
}

// MARK: - Presenter

@MainActor
final class SimpleShufflePresenterTests: XCTestCase {

    func test_初期ViewDataは登録順_QA9_1と不一致_既知の課題() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]
        let presenter = SimpleShufflePresenter(
            interactor: SimpleShuffleInteractor(attendees: attendees)
        )

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["太郎", "花子"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2])
        XCTAssertEqual(presenter.viewData.rows.map(\.id), attendees.map(\.id))
    }

    func test_シャッフル後も集合は不変で番号は1始まり() {
        let attendees = [Attendee(name: "A"), Attendee(name: "B"), Attendee(name: "C")]
        let presenter = SimpleShufflePresenter(
            interactor: SimpleShuffleInteractor(attendees: attendees)
        )

        presenter.didTapShuffle()

        XCTAssertEqual(Set(presenter.viewData.rows.map(\.id)), Set(attendees.map(\.id)))
        XCTAssertEqual(Set(presenter.viewData.rows.map(\.name)), ["A", "B", "C"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2, 3])
    }

    func test_共有は初期の登録順の名前配列をShareへ渡す() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]
        let share = ShareRouter.assemblePresenter()
        let presenter = SimpleShufflePresenter(
            interactor: SimpleShuffleInteractor(attendees: attendees),
            share: share
        )

        presenter.didTapShare()

        XCTAssertEqual(share.route, .selection)
        XCTAssertEqual(share.subject, .numberedList(attendees: ["太郎", "花子"]))
        XCTAssertEqual(
            ShareInteractor().makeShareText(for: share.subject!),
            "【サクッと席決め】シャッフル結果\n1番席: 太郎\n2番席: 花子"
        )
    }

    func test_シャッフル後の共有は現在の並びの名前配列をShareへ渡す() {
        let attendees = (1...8).map { Attendee(name: "N\($0)") }
        let share = ShareRouter.assemblePresenter()
        let presenter = SimpleShufflePresenter(
            interactor: SimpleShuffleInteractor(attendees: attendees),
            share: share
        )
        let originalNames = attendees.map(\.name)

        var currentNames = originalNames
        for _ in 0..<100 {
            presenter.didTapShuffle()
            currentNames = presenter.viewData.rows.map(\.name)
            if currentNames != originalNames {
                break
            }
        }
        XCTAssertNotEqual(currentNames, originalNames, "8名のシャッフルが100回とも元の順のまま")

        presenter.didTapShare()

        XCTAssertEqual(share.route, .selection)
        XCTAssertEqual(share.subject, .numberedList(attendees: currentNames))
        XCTAssertEqual(
            ShareInteractor().makeShareText(for: share.subject!),
            ShareInteractor().makeShareText(for: .numberedList(attendees: currentNames))
        )
    }
}

// MARK: - Router

@MainActor
final class SimpleShuffleRouterTests: XCTestCase {

    func test_assembleModuleは参加者を受け取って画面を返す() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]

        _ = SimpleShuffleRouter.assembleModule(attendees: attendees)
    }

    func test_空配列でもassembleできる() {
        _ = SimpleShuffleRouter.assembleModule(attendees: [])
    }
}
