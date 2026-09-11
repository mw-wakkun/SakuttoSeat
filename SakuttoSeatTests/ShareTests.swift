//
//  ShareTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 5（共有モジュールの回帰）
//  refactor_simple.md Phase 2（番号札は ViewData 駆動。number を再計算しない）
//
//  Phase 4 まで `SeatingChartInteractor` / `SimpleShuffleView` が持っていた
//  共有テキストの整形を Share モジュールへ移送したため、検証もここへ移した。
//  refactor_Ad.md Phase 2（Router へ Gateway を注入。Presenter 分岐のケース追加は Phase 4）
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

    private func makeNumberedList(
        _ names: [String],
        numbers: [Int]? = nil
    ) -> SimpleShuffleViewData {
        guard !names.isEmpty else { return .empty }
        let assignedNumbers = numbers ?? Array(1...names.count)
        return SimpleShuffleViewDataBuilder.build(
            seats: zip(names, assignedNumbers).map { name, number in
                NumberedSeat(id: UUID(), name: name, number: number)
            }
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

    func test_番号札の共有テキストは渡した順の番号付きになる() {
        let text = ShareInteractor().makeShareText(for: .numberedList(makeNumberedList(["太郎", "花子"])))

        XCTAssertEqual(text, "【サクッと席決め】シャッフル結果\n1番席: 太郎\n2番席: 花子")
    }

    func test_番号札テキストの番号はViewDataのnumberを使う() {
        let viewData = makeNumberedList(["花子", "太郎"], numbers: [10, 3])
        let text = ShareInteractor().makeShareText(for: .numberedList(viewData))

        XCTAssertEqual(text, "【サクッと席決め】シャッフル結果\n10番席: 花子\n3番席: 太郎")
        XCTAssertFalse(text.contains("1番席:"))
        XCTAssertFalse(text.contains("2番席:"))
    }

    func test_番号札の空配列は見出しだけになる() {
        let text = ShareInteractor().makeShareText(for: .numberedList(.empty))

        XCTAssertEqual(text, "【サクッと席決め】シャッフル結果")
    }

    // MARK: - 広告要否

    func test_画像共有は常にリワード広告が必要() {
        XCTAssertEqual(ShareInteractor().imageShareRequirement(), .rewardedAd)
    }
}

// MARK: - Presenter
//
// 提示を伴う経路（シェアシート・広告）は実機/シミュレータの提示状態に依存するため、
// ここでは route と保持した subject だけを検証する。

@MainActor
final class SharePresenterTests: XCTestCase {

    private func makePresenter(
        rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayFake()
    ) -> SharePresenter {
        SharePresenter(
            interactor: ShareInteractor(),
            router: ShareRouter(rewardedAd: rewardedAd)
        )
    }

    func test_共有ボタンで選択シートが開き対象が保持される() {
        let presenter = makePresenter()
        let viewData = SimpleShuffleViewDataBuilder.build(
            seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
        )

        presenter.didTapShare(subject: .numberedList(viewData))

        XCTAssertEqual(presenter.route, .selection)
        XCTAssertEqual(presenter.subject, .numberedList(viewData))
    }

    func test_共有対象が未設定なら選択しても何も起きない() {
        let presenter = makePresenter()

        presenter.didSelectKind(.text)

        XCTAssertNil(presenter.route)
    }

    func test_ルートは明示的に閉じられる() {
        let presenter = makePresenter()
        presenter.didTapShare(
            subject: .numberedList(
                SimpleShuffleViewDataBuilder.build(
                    seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
                )
            )
        )

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
    }

    // MARK: - リワード提示（Presenter 分岐のケース追加は Phase 4）
    //
    // 期待（現行 SharePresenter.didConfirmImageShare）:
    // - Fake.notReady → route == .alert(.adNotReady)。画像シェアは呼ばない
    // - Fake.success → 画像出力経路へ進む
    // - Fake.notEarned / failed → route なし、共有なし

    func test_画像共有確認_広告未準備ならアラート() throws {
        throw XCTSkip("Phase 4 で SharePresenter のリワード分岐を有効化する")
    }

    func test_画像共有確認_視聴完了なら画像出力へ進む() throws {
        throw XCTSkip("Phase 4 で SharePresenter のリワード分岐を有効化する")
    }

    func test_画像共有確認_未獲得と失敗では共有しない() throws {
        throw XCTSkip("Phase 4 で SharePresenter のリワード分岐を有効化する")
    }
}

// MARK: - Router（Gateway 注入）

@MainActor
final class ShareRouterTests: XCTestCase {

    func test_presentRewardedAdは注入したGatewayを1回呼ぶ() async throws {
        let fake = RewardedAdGatewayFake(outcome: .success)
        let router = ShareRouter(rewardedAd: fake)

        try await router.presentRewardedAd()

        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_presentRewardedAdはFakeのnotReadyを再throwする() async {
        let fake = RewardedAdGatewayFake(outcome: .notReady)
        let router = ShareRouter(rewardedAd: fake)

        do {
            try await router.presentRewardedAd()
            XCTFail("expected notReady")
        } catch RewardedAdError.notReady {
            XCTAssertEqual(fake.presentCallCount, 1)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
