//
//  ShareTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 5（共有モジュールの回帰）
//
//  Phase 4 まで `SeatingChartInteractor` / `SimpleShuffleView` が持っていた
//  共有テキストの整形を Share モジュールへ移送したため、検証もここへ移した。
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

@MainActor
final class ShareInteractorTests: XCTestCase {

    private func makeViewData(names: [String], globalColumnCount: Int = 2) -> SeatingChartViewData {
        let interactor = SeatingChartInteractor(attendees: names.map { Attendee(name: $0) })
        return SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: globalColumnCount
        )
    }

    // MARK: - 座席表

    func test_共有テキストはテーブル名と配置を含む() {
        let text = ShareInteractor().makeShareText(for: .seatingChart(makeViewData(names: ["A", "B"])))

        XCTAssertTrue(text.contains("【サクッと席決め】"))
        XCTAssertTrue(text.contains("テーブルA"))
        XCTAssertTrue(text.contains("A"))
        XCTAssertTrue(text.contains("#サクッと席決め"))
    }

    func test_共有テキスト_2列なら左右で表記される() {
        let text = ShareInteractor().makeShareText(for: .seatingChart(makeViewData(names: ["太郎", "花子"])))

        XCTAssertTrue(text.contains("🪑 [1列目 · 左] : 太郎"))
        XCTAssertTrue(text.contains("🪑 [1列目 · 右] : 花子"))
    }

    func test_共有テキスト_3列以上なら行列で表記される() {
        let interactor = SeatingChartInteractor(attendees: ["A", "B", "C", "D"].map { Attendee(name: $0) })
        _ = interactor.updateAllTables(
            TableUpdateRequest(
                tableID: interactor.currentTables()[0].id,
                name: "テーブルA",
                capacity: 4,
                columnCount: 3,
                layoutDirection: .none,
                layoutText: "",
                applyToAll: true
            )
        )
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        let text = ShareInteractor().makeShareText(for: .seatingChart(viewData))

        XCTAssertTrue(text.contains("🪑 [1行1列目] : A"))
        XCTAssertTrue(text.contains("🪑 [2行1列目] : D"))
    }

    func test_共有テキスト_空席は出力されずメンバー0人なら案内が出る() {
        let viewData = makeViewData(names: [])

        let text = ShareInteractor().makeShareText(for: .seatingChart(viewData))

        XCTAssertTrue(text.contains("（まだメンバーが配置されていません）"))
        XCTAssertFalse(text.contains("空席"))
    }

    func test_共有テキスト_追加ボタンはテーブルとして出力されない() {
        let viewData = makeViewData(names: ["A"])

        let text = ShareInteractor().makeShareText(for: .seatingChart(viewData))

        XCTAssertEqual(text.components(separatedBy: "▼ ").count - 1, 1)
    }

    // MARK: - 番号札

    func test_番号札の共有テキストは登録順の番号付きになる() {
        let text = ShareInteractor().makeShareText(for: .numberedList(attendees: ["太郎", "花子"]))

        XCTAssertEqual(text, "【サクッと席決め】シャッフル結果\n1番席: 太郎\n2番席: 花子")
    }

    // MARK: - 広告要否

    func test_画像共有は常にリワード広告が必要() {
        XCTAssertEqual(ShareInteractor().imageShareRequirement(), .rewardedAd)
    }
}

// MARK: - Presenter
//
// 提示を伴う経路（シェアシート・広告）は実機/シミュレータの提示状態に依存するため、
// ここでは route の遷移だけを検証する。

@MainActor
final class SharePresenterTests: XCTestCase {

    private func makePresenter() -> SharePresenter {
        ShareRouter.assemblePresenter()
    }

    func test_共有ボタンで選択シートが開く() {
        let presenter = makePresenter()

        presenter.didTapShare(subject: .numberedList(attendees: ["A"]))

        XCTAssertEqual(presenter.route, .selection)
    }

    func test_共有対象が未設定なら選択しても何も起きない() {
        let presenter = makePresenter()

        presenter.didSelectKind(.text)

        XCTAssertNil(presenter.route)
    }

    func test_ルートは明示的に閉じられる() {
        let presenter = makePresenter()
        presenter.didTapShare(subject: .numberedList(attendees: ["A"]))

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
    }
}
