//
//  SimpleShuffleTests.swift
//  SakuttoSeatTests
//
//  refactor_simple.md Phase 0〜4（番号札の回帰。初期表示は抽選済み。Share は ViewData を渡す）
//  v2.1 Phase 2（Snapshot 高画質の幅・余白）
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class SimpleShuffleInteractorTests: XCTestCase {

    func test_初期状態は集合不変で番号は1始まり_2名以上なら順序は登録順と異なることがある() {
        let attendees = (1...8).map { Attendee(name: "N\($0)") }
        let originalIDs = attendees.map(\.id)
        let originalNames = attendees.map(\.name)

        let first = SimpleShuffleInteractor(attendees: attendees).allSeats()
        XCTAssertEqual(Set(first.map(\.id)), Set(originalIDs))
        XCTAssertEqual(Set(first.map(\.name)), Set(originalNames))
        XCTAssertEqual(first.map(\.number), Array(1...8))

        var foundDifferentOrder = first.map(\.id) != originalIDs
        if !foundDifferentOrder {
            for _ in 0..<100 {
                let seats = SimpleShuffleInteractor(attendees: attendees).allSeats()
                if seats.map(\.id) != originalIDs {
                    foundDifferentOrder = true
                    break
                }
            }
        }
        XCTAssertTrue(foundDifferentOrder, "8名の初期シャッフルが100回とも登録順のまま")
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
        XCTAssertTrue(empty.allSeats().isEmpty)
        XCTAssertTrue(empty.shuffle().isEmpty)

        let attendee = Attendee(name: "A")
        let single = SimpleShuffleInteractor(attendees: [attendee])
        XCTAssertEqual(single.allSeats().map(\.id), [attendee.id])
        XCTAssertEqual(single.allSeats().map(\.name), ["A"])
        XCTAssertEqual(single.allSeats().map(\.number), [1])

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
        XCTAssertTrue(viewData.isEmpty)
        XCTAssertFalse(viewData.canShuffle)
    }

    func test_2名以上ならcanShuffle_1名以下はfalse() {
        XCTAssertFalse(
            SimpleShuffleViewDataBuilder.build(seats: [
                NumberedSeat(id: UUID(), name: "A", number: 1)
            ]).canShuffle
        )

        let two = SimpleShuffleViewDataBuilder.build(seats: [
            NumberedSeat(id: UUID(), name: "A", number: 1),
            NumberedSeat(id: UUID(), name: "B", number: 2)
        ])
        XCTAssertTrue(two.canShuffle)
        XCTAssertFalse(two.isEmpty)
    }

    func test_発表Copyは入口と終了が対になる() {
        XCTAssertEqual(PresentationCopy.presentAccessibilityLabel, "発表")
        XCTAssertEqual(PresentationCopy.presentToolbarTitle, "発表")
        XCTAssertEqual(PresentationCopy.dismissAccessibilityLabel, "発表を終了")
        XCTAssertTrue(PresentationCopy.tapToDismissHint.contains("閉じるボタン"))
        XCTAssertFalse(PresentationCopy.tapToDismissHint.contains("終了"))
        XCTAssertEqual(PresentationCopy.seatingPresentDisabledHint, "テーブルがないと発表できません")
        XCTAssertEqual(PresentationCopy.numberedPresentDisabledHint, "参加者がいないと発表できません")
    }

    func test_画面見出しと共有画像見出しは意図的に別文言() {
        XCTAssertNotEqual(SimpleShuffleCopy.listHeader, SimpleShuffleCopy.snapshotTitle)
        XCTAssertTrue(SimpleShuffleCopy.snapshotTitle.contains("番号札"))
    }

    func test_SnapshotView_標準と高画質で幅と余白が分かれる() {
        let viewData = SimpleShuffleViewDataBuilder.build(
            seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
        )
        let standard = SimpleShuffleSnapshotView(viewData: viewData)
        let highRes = SimpleShuffleSnapshotView(viewData: viewData, layout: .highRes)

        XCTAssertEqual(standard.layout, .standard)
        XCTAssertEqual(standard.layout.exportWidth, 400)
        XCTAssertEqual(standard.layout.contentPadding, 20)
        XCTAssertEqual(standard.layout.rowSpacing, 8)

        XCTAssertEqual(highRes.layout, .highRes)
        XCTAssertEqual(highRes.layout.exportWidth, 680)
        XCTAssertEqual(highRes.layout.contentPadding, 8)
        XCTAssertGreaterThan(highRes.layout.exportWidth, standard.layout.exportWidth)
        XCTAssertGreaterThan(highRes.layout.rowSpacing, standard.layout.rowSpacing)
        XCTAssertGreaterThan(highRes.layout.rowPadding, standard.layout.rowPadding)
        XCTAssertEqual(SimpleShuffleSnapshotView.exportWidth, 400)
        XCTAssertEqual(SimpleShuffleSnapshotView.highResExportWidth, 680)
        XCTAssertEqual(SimpleShuffleSnapshotView.highResMultiColumnExportWidth, 834)
        XCTAssertEqual(SimpleShuffleSnapshotView.highResRowsPerColumn, 30)
    }

    func test_高画質は人数に応じて列と幅を増やす() {
        let highRes = SimpleShuffleSnapshotView.Layout.highRes
        let standard = SimpleShuffleSnapshotView.Layout.standard

        XCTAssertEqual(standard.columnCount(rowCount: FeatureLimit.maxAttendeeCount), 1)
        XCTAssertEqual(highRes.columnCount(rowCount: 1), 1)
        XCTAssertEqual(highRes.columnCount(rowCount: 30), 1)
        XCTAssertEqual(highRes.columnCount(rowCount: 31), 2)
        XCTAssertEqual(highRes.columnCount(rowCount: 60), 2)
        XCTAssertEqual(highRes.columnCount(rowCount: 61), 3)
        XCTAssertEqual(highRes.columnCount(rowCount: FeatureLimit.maxAttendeeCount), 4)

        XCTAssertEqual(highRes.exportWidth(rowCount: 1), SimpleShuffleSnapshotView.highResExportWidth)
        XCTAssertEqual(
            highRes.exportWidth(rowCount: FeatureLimit.maxAttendeeCount),
            SimpleShuffleSnapshotView.highResMultiColumnExportWidth
        )
        XCTAssertGreaterThan(
            highRes.exportWidth(rowCount: FeatureLimit.maxAttendeeCount),
            highRes.exportWidth(rowCount: 1)
        )
    }
}

// MARK: - Presenter

@MainActor
final class SimpleShufflePresenterTests: XCTestCase {

    private func makePresenter(
        attendees: [Attendee],
        share: SharePresenter? = nil
    ) -> SimpleShufflePresenter {
        SimpleShufflePresenter(
            interactor: SimpleShuffleInteractor(attendees: attendees),
            share: share ?? ShareRouter.assemblePresenter()
        )
    }

    func test_初期ViewDataは集合不変で番号は1始まり() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子"), Attendee(name: "次郎")]
        let presenter = makePresenter(attendees: attendees)

        XCTAssertEqual(Set(presenter.viewData.rows.map(\.id)), Set(attendees.map(\.id)))
        XCTAssertEqual(Set(presenter.viewData.rows.map(\.name)), ["太郎", "花子", "次郎"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2, 3])
        XCTAssertTrue(presenter.viewData.canShuffle)
        XCTAssertFalse(presenter.viewData.isEmpty)
    }

    func test_1名以下ではcanShuffleがfalse() {
        XCTAssertFalse(makePresenter(attendees: []).viewData.canShuffle)
        XCTAssertTrue(makePresenter(attendees: []).viewData.isEmpty)
        XCTAssertFalse(makePresenter(attendees: [Attendee(name: "A")]).viewData.canShuffle)
        XCTAssertTrue(
            makePresenter(attendees: [Attendee(name: "A"), Attendee(name: "B")]).viewData.canShuffle
        )
    }

    func test_シャッフル後も集合は不変で番号は1始まり() {
        let attendees = [Attendee(name: "A"), Attendee(name: "B"), Attendee(name: "C")]
        let presenter = makePresenter(attendees: attendees)

        presenter.didTapShuffle()

        XCTAssertEqual(Set(presenter.viewData.rows.map(\.id)), Set(attendees.map(\.id)))
        XCTAssertEqual(Set(presenter.viewData.rows.map(\.name)), ["A", "B", "C"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2, 3])
    }

    func test_注入したShareをProtocol経由で公開する() {
        let share = ShareRouter.assemblePresenter()
        let presenter: any SimpleShufflePresenterProtocol = makePresenter(
            attendees: [Attendee(name: "A")],
            share: share
        )

        XCTAssertTrue(presenter.share === share)
    }

    func test_空状態では発表できない() {
        let presenter = makePresenter(attendees: [])

        presenter.didTapPresent()

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_発表はタップ時点のスナップショットをCover用Routeに載せる() {
        let presenter = makePresenter(attendees: [Attendee(name: "太郎"), Attendee(name: "花子")])
        let snapshot = presenter.viewData

        presenter.didTapPresent()

        guard case .presentation(_, let presented) = presenter.route else {
            return XCTFail("発表 Route が開くべき")
        }
        XCTAssertEqual(presented, snapshot)
        XCTAssertTrue(presenter.route?.presentsAsFullScreenCover == true)
        presenter.dismissRoute()
    }

    func test_発表中は共有もシャッフルも出さない() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]
        let presenter = makePresenter(attendees: attendees)
        presenter.didTapPresent()
        let opened = presenter.route
        let viewData = presenter.viewData

        presenter.didTapShare()
        presenter.didTapShuffle()

        XCTAssertEqual(presenter.route, opened)
        XCTAssertNil(presenter.share.route)
        XCTAssertEqual(presenter.viewData, viewData)
        presenter.dismissRoute()
    }

    func test_発表を閉じると通常操作に戻る() {
        let presenter = makePresenter(attendees: [Attendee(name: "太郎")])
        presenter.didTapPresent()
        XCTAssertNotNil(presenter.route)

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
        presenter.didTapShare()
        XCTAssertEqual(presenter.share.route, .selection)
    }

    func test_共有は初期ViewDataをShareへ渡す() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]
        let share = ShareRouter.assemblePresenter()
        let presenter = makePresenter(attendees: attendees, share: share)
        let viewData = presenter.viewData

        presenter.didTapShare()

        XCTAssertEqual(share.route, .selection)
        XCTAssertEqual(share.subject, .numberedList(viewData))
        let expectedLines = viewData.rows.map { "\($0.number)番席: \($0.name)" }
        XCTAssertEqual(
            ShareInteractor().makeShareText(for: share.subject!),
            "【サクッと席決め】シャッフル結果\n" + expectedLines.joined(separator: "\n")
        )
    }

    func test_シャッフル後の共有は現在のViewDataをShareへ渡す() {
        let attendees = (1...8).map { Attendee(name: "N\($0)") }
        let share = ShareRouter.assemblePresenter()
        let presenter = makePresenter(attendees: attendees, share: share)
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

        let currentViewData = presenter.viewData
        presenter.didTapShare()

        XCTAssertEqual(share.route, .selection)
        XCTAssertEqual(share.subject, .numberedList(currentViewData))
        let expectedLines = currentViewData.rows.map { "\($0.number)番席: \($0.name)" }
        XCTAssertEqual(
            ShareInteractor().makeShareText(for: share.subject!),
            "【サクッと席決め】シャッフル結果\n" + expectedLines.joined(separator: "\n")
        )
    }
}

