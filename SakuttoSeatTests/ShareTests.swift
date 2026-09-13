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
//  refactor_Ad.md Phase 4（Fake Gateway で未準備 / 成功 / 未獲得・失敗を固定）
//  v2.1 Phase 1（CSV フォーマットと書き出し解放の状態遷移）
//

import UIKit
import XCTest
@testable import SakuttoSeat

// MARK: - ExportUnlock

final class ExportUnlockStateTests: XCTestCase {

    func test_初期状態は未解放() {
        XCTAssertFalse(ExportUnlockState().isSessionUnlocked)
    }

    func test_grantで解放され以降は維持される() {
        let unlock = ExportUnlockState()

        unlock.grantSessionUnlock()
        unlock.grantSessionUnlock()

        XCTAssertTrue(unlock.isSessionUnlocked)
    }

    func test_列数解放とはインスタンスが独立している() {
        let export = ExportUnlockState()
        let feature = FeatureUnlockState(isSessionUnlocked: true)

        XCTAssertTrue(feature.isSessionUnlocked)
        XCTAssertFalse(export.isSessionUnlocked)

        export.grantSessionUnlock()

        XCTAssertTrue(export.isSessionUnlocked)
        XCTAssertTrue(feature.isSessionUnlocked)
        XCTAssertFalse(
            ObjectIdentifier(SessionExportUnlock.shared) == ObjectIdentifier(SessionFeatureUnlock.shared)
        )
    }
}

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

    // MARK: - CSV

    func test_座席表CSVはBOMとヘッダと行列を含む() {
        let csv = ShareInteractor().makeCSV(for: .seatingChart(makeViewData(names: ["太郎", "花子"])))

        XCTAssertTrue(csv.hasPrefix(ShareInteractor.utf8BOM))
        XCTAssertFalse(csv.contains("\r\n"))
        XCTAssertEqual(
            csv,
            ShareInteractor.utf8BOM + "テーブル,行,列,氏名\nテーブルA,1,1,太郎\nテーブルA,1,2,花子"
        )
    }

    func test_座席表CSVの行列はテキスト共有と同じ席インデックス() {
        let interactor = SeatingChartInteractor(attendees: ["A", "B", "C", "D"].map { Attendee(name: $0) })
        _ = interactor.updateAllTables(
            TableUpdateRequest(
                tableID: interactor.currentTables()[0].id,
                name: "A卓",
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

        let csv = ShareInteractor().makeCSV(for: .seatingChart(viewData))

        XCTAssertTrue(csv.contains("A卓,1,1,A"))
        XCTAssertTrue(csv.contains("A卓,2,1,D"))
        XCTAssertFalse(csv.contains("ロック"))
    }

    func test_座席表CSVは空席を含まない() {
        let csv = ShareInteractor().makeCSV(for: .seatingChart(makeViewData(names: ["太郎"])))

        XCTAssertTrue(csv.contains("太郎"))
        XCTAssertFalse(csv.contains("空席"))
        XCTAssertEqual(csv.components(separatedBy: "\n").count, 2)
    }

    func test_番号札CSVはBOMと番号氏名になる() {
        let csv = ShareInteractor().makeCSV(for: .numberedList(makeNumberedList(["太郎", "花子"])))

        XCTAssertEqual(csv, ShareInteractor.utf8BOM + "番号,氏名\n1,太郎\n2,花子")
    }

    func test_番号札CSVの番号はViewDataのnumberを使う() {
        let csv = ShareInteractor().makeCSV(for: .numberedList(makeNumberedList(["花子", "太郎"], numbers: [10, 3])))

        XCTAssertEqual(csv, ShareInteractor.utf8BOM + "番号,氏名\n10,花子\n3,太郎")
    }

    func test_CSV_氏名のカンマはダブルクォートでエスケープ() {
        let csv = ShareInteractor().makeCSV(for: .numberedList(makeNumberedList(["山田, 太郎"])))

        XCTAssertTrue(csv.contains("\"山田, 太郎\""))
    }

    func test_CSVファイル名は対象と日付を含む() {
        let now = Date(timeIntervalSince1970: 1_704_067_200)
        let utc = TimeZone(identifier: "UTC")!
        let interactor = ShareInteractor()

        XCTAssertEqual(
            interactor.makeCSVFileName(for: .seatingChart(.empty), now: now, timeZone: utc),
            "座席表_20240101.csv"
        )
        XCTAssertEqual(
            interactor.makeCSVFileName(for: .numberedList(.empty), now: now, timeZone: utc),
            "番号札_20240101.csv"
        )
    }

    // MARK: - 広告要否 / 解放フラグ

    func test_テキストは常に広告不要() {
        let locked = ShareInteractor()
        let unlocked = ShareInteractor(exportUnlock: ExportUnlockState(isSessionUnlocked: true))

        XCTAssertEqual(locked.exportRequirement(for: .text), .none)
        XCTAssertEqual(unlocked.exportRequirement(for: .text), .none)
    }

    func test_有料3種は未解放ならリワードが必要() {
        let interactor = ShareInteractor()

        XCTAssertEqual(interactor.exportRequirement(for: .image), .rewardedAd)
        XCTAssertEqual(interactor.exportRequirement(for: .highResImage), .rewardedAd)
        XCTAssertEqual(interactor.exportRequirement(for: .csv), .rewardedAd)
        XCTAssertFalse(interactor.isExportUnlocked)
    }

    func test_書き出し解放後は有料3種も広告不要() {
        let unlock = ExportUnlockState()
        let interactor = ShareInteractor(exportUnlock: unlock)

        interactor.grantExportUnlock()

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertTrue(interactor.isExportUnlocked)
        XCTAssertEqual(interactor.exportRequirement(for: .image), .none)
        XCTAssertEqual(interactor.exportRequirement(for: .highResImage), .none)
        XCTAssertEqual(interactor.exportRequirement(for: .csv), .none)
    }

    func test_列数解放済みでもCSVはリワードが必要() {
        let featureUnlock = FeatureUnlockState(isSessionUnlocked: true)
        let interactor = ShareInteractor(exportUnlock: ExportUnlockState())

        XCTAssertTrue(featureUnlock.isSessionUnlocked)
        XCTAssertEqual(interactor.exportRequirement(for: .csv), .rewardedAd)
        XCTAssertEqual(interactor.exportRequirement(for: .image), .rewardedAd)
        XCTAssertEqual(interactor.exportRequirement(for: .highResImage), .rewardedAd)
    }

    func test_選択肢は4種でテキスト以外は解放で字幕が変わる() {
        XCTAssertEqual(ShareSelectionKind.allCases, [.text, .image, .highResImage, .csv])
        XCTAssertEqual(ShareCopy.subtitle(for: .text, isExportUnlocked: false), "無料ですぐに共有できます")
        XCTAssertEqual(ShareCopy.subtitle(for: .text, isExportUnlocked: true), "無料ですぐに共有できます")
        XCTAssertEqual(ShareCopy.subtitle(for: .image, isExportUnlocked: false), "動画を見てきれいな座席表画像を保存・送信")
        XCTAssertEqual(ShareCopy.subtitle(for: .csv, isExportUnlocked: false), "Excel・名簿ソフトで二次利用")
        XCTAssertEqual(ShareCopy.subtitle(for: .highResImage, isExportUnlocked: false), "余白カット・印刷や投影向き")
        for kind in [ShareSelectionKind.image, .highResImage, .csv] {
            XCTAssertEqual(ShareCopy.subtitle(for: kind, isExportUnlocked: true), "この起動中はすぐに書き出せます")
        }
    }
}

// MARK: - Presenter
//
// シェアシートの実提示はシミュレータ状態に依存するため、Spy で呼び出し有無だけを見る。
// リワード分岐は Fake Gateway の outcome で固定する（Phase 4）。

@MainActor
final class SharePresenterTests: XCTestCase {

    private func makePresenter(
        rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayFake(),
        exportUnlock: ExportUnlockState = ExportUnlockState()
    ) -> SharePresenter {
        SharePresenter(
            interactor: ShareInteractor(exportUnlock: exportUnlock),
            router: ShareRouter(rewardedAd: rewardedAd)
        )
    }

    private func makeExportSUT(
        outcome: RewardedAdGatewayFake.Outcome = .success,
        exportUnlock: ExportUnlockState = ExportUnlockState()
    ) -> (presenter: SharePresenter, router: ShareRouterSpy, fake: RewardedAdGatewayFake, unlock: ExportUnlockState) {
        let fake = RewardedAdGatewayFake(outcome: outcome)
        let router = ShareRouterSpy(rewardedAd: fake)
        let presenter = SharePresenter(
            interactor: ShareInteractor(exportUnlock: exportUnlock),
            router: router
        )
        presenter.didTapShare(
            subject: .numberedList(
                SimpleShuffleViewDataBuilder.build(
                    seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
                )
            )
        )
        return (presenter, router, fake, exportUnlock)
    }

    @discardableResult
    private func confirmExport(
        _ presenter: SharePresenter,
        kind: ShareSelectionKind = .image
    ) async throws -> ShareSubject {
        let subject = try XCTUnwrap(presenter.subject)
        presenter.dismissRoute()
        await presenter.confirmExport(for: subject, kind: kind)
        return subject
    }

    func test_共有ボタンで選択シートが開き対象が保持される() {
        let presenter = makePresenter()
        let viewData = SimpleShuffleViewDataBuilder.build(
            seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
        )

        presenter.didTapShare(subject: .numberedList(viewData))

        XCTAssertEqual(presenter.route, .selection)
        XCTAssertEqual(presenter.subject, .numberedList(viewData))
        XCTAssertFalse(presenter.isExportUnlocked)
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

    // MARK: - リワード提示（Phase 4 / v2.1）

    func test_画像共有確認_広告未準備ならアラート() async throws {
        let sut = makeExportSUT(outcome: .notReady)

        try await confirmExport(sut.presenter)

        XCTAssertEqual(sut.presenter.route, .alert(.adNotReady))
        XCTAssertEqual(sut.fake.presentCallCount, 1)
        XCTAssertEqual(sut.router.makeShareImageCallCount, 0)
        XCTAssertEqual(sut.router.presentedImageCount, 0)
        XCTAssertFalse(sut.unlock.isSessionUnlocked)
    }

    func test_画像共有確認_視聴完了なら解放して画像出力へ進む() async throws {
        let sut = makeExportSUT(outcome: .success)

        try await confirmExport(sut.presenter, kind: .image)

        XCTAssertNil(sut.presenter.route)
        XCTAssertEqual(sut.fake.presentCallCount, 1)
        XCTAssertEqual(sut.router.makeShareImageCallCount, 1)
        XCTAssertEqual(sut.router.presentedImageCount, 1)
        XCTAssertTrue(sut.unlock.isSessionUnlocked)
        XCTAssertTrue(sut.presenter.isExportUnlocked)
    }

    func test_CSV確認_視聴完了なら解放してCSV提示へ進む() async throws {
        let sut = makeExportSUT(outcome: .success)

        try await confirmExport(sut.presenter, kind: .csv)

        XCTAssertNil(sut.presenter.route)
        XCTAssertEqual(sut.fake.presentCallCount, 1)
        XCTAssertEqual(sut.router.presentedCSVCount, 1)
        XCTAssertEqual(sut.router.makeShareImageCallCount, 0)
        XCTAssertTrue(sut.unlock.isSessionUnlocked)
        XCTAssertEqual(sut.router.lastPresentedCSV?.hasPrefix(ShareInteractor.utf8BOM), true)
    }

    func test_画像共有確認_未獲得と失敗では共有も解放もしない() async throws {
        for outcome in [RewardedAdGatewayFake.Outcome.notEarned, .failed("network")] {
            let sut = makeExportSUT(outcome: outcome)

            try await confirmExport(sut.presenter)

            XCTAssertNil(sut.presenter.route, "outcome: \(outcome)")
            XCTAssertEqual(sut.fake.presentCallCount, 1, "outcome: \(outcome)")
            XCTAssertEqual(sut.router.makeShareImageCallCount, 0, "outcome: \(outcome)")
            XCTAssertEqual(sut.router.presentedImageCount, 0, "outcome: \(outcome)")
            XCTAssertFalse(sut.unlock.isSessionUnlocked, "outcome: \(outcome)")
        }
    }

    func test_未解放の有料形式は確認アラートになる() async {
        let sut = makeExportSUT()
        let subject = sut.presenter.subject!

        await sut.presenter.exportOrRequestUnlock(kind: .image, for: subject)
        XCTAssertEqual(sut.presenter.route, .alert(.confirmImageShareWithAd))

        await sut.presenter.exportOrRequestUnlock(kind: .highResImage, for: subject)
        XCTAssertEqual(sut.presenter.route, .alert(.confirmHighResImageShareWithAd))

        await sut.presenter.exportOrRequestUnlock(kind: .csv, for: subject)
        XCTAssertEqual(sut.presenter.route, .alert(.confirmCSVExportWithAd))
        XCTAssertEqual(sut.fake.presentCallCount, 0)
        XCTAssertEqual(sut.router.presentedCSVCount, 0)
    }

    func test_解放済みなら有料形式は確認も動画もスキップする() async {
        let sut = makeExportSUT(exportUnlock: ExportUnlockState(isSessionUnlocked: true))
        let subject = sut.presenter.subject!

        await sut.presenter.exportOrRequestUnlock(kind: .csv, for: subject)

        XCTAssertNil(sut.presenter.route)
        XCTAssertEqual(sut.fake.presentCallCount, 0)
        XCTAssertEqual(sut.router.presentedCSVCount, 1)
        XCTAssertEqual(sut.router.presentedImageCount, 0)
    }

    func test_高画質はPhase1では標準画像と同じ出力経路() async {
        let sut = makeExportSUT(exportUnlock: ExportUnlockState(isSessionUnlocked: true))
        let subject = sut.presenter.subject!

        await sut.presenter.exportOrRequestUnlock(kind: .highResImage, for: subject)

        XCTAssertEqual(sut.router.makeShareImageCallCount, 1)
        XCTAssertEqual(sut.router.presentedImageCount, 1)
        XCTAssertEqual(sut.fake.presentCallCount, 0)
    }

    func test_ルートを閉じると広告待ちの画像共有は破棄される() async throws {
        let hanging = RewardedAdGatewayHangingFake()
        let router = ShareRouterSpy(rewardedAd: hanging)
        let unlock = ExportUnlockState()
        let presenter = SharePresenter(
            interactor: ShareInteractor(exportUnlock: unlock),
            router: router
        )
        presenter.didTapShare(
            subject: .numberedList(
                SimpleShuffleViewDataBuilder.build(
                    seats: [NumberedSeat(id: UUID(), name: "A", number: 1)]
                )
            )
        )
        let subject = try XCTUnwrap(presenter.subject)

        let task = Task { @MainActor in
            await presenter.confirmExport(for: subject, kind: .image)
        }
        await hanging.waitUntilPresentStarted()
        presenter.dismissRoute()
        hanging.finishSuccessfully()
        await task.value

        XCTAssertNil(presenter.route)
        XCTAssertEqual(router.makeShareImageCallCount, 0)
        XCTAssertEqual(router.presentedImageCount, 0)
        XCTAssertFalse(unlock.isSessionUnlocked)
    }
}

private final class ShareRouterSpy: ShareRouter {
    private(set) var makeShareImageCallCount = 0
    private(set) var presentedImageCount = 0
    private(set) var presentedCSVCount = 0
    private(set) var lastPresentedCSV: String?

    override func makeShareImage(for subject: ShareSubject) -> UIImage? {
        makeShareImageCallCount += 1
        return UIImage()
    }

    override func presentShareSheet(image: UIImage) async {
        presentedImageCount += 1
    }

    override func presentShareSheet(csv: String, fileName: String) async -> Bool {
        presentedCSVCount += 1
        lastPresentedCSV = csv
        return true
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

    func test_assemblePresenterはSessionExportUnlockを使う() {
        let presenter = ShareRouter.assemblePresenter()

        XCTAssertEqual(presenter.isExportUnlocked, SessionExportUnlock.shared.isSessionUnlocked)
    }
}
