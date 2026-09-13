//
//  AttendeeListPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0 / Phase 1 / Phase 2 / Phase 3 / Phase 4 / Phase 5
//  refactor_favorite.md Phase 0（お気に入りシートの Gateway 共有を断言）
//  refactor_favorite.md Phase 4（シート期間中の子 Presenter identity）
//  refactor_groupFavorite.md Phase 4（Gateway は Interactor init 注入。Protocol 経由 attach は無い）
//  refactor_groupFavorite.md Phase 5（失敗ダブルは Support/GroupFavoriteTestGateways）
//  意図メソッド → ViewData / Route の契約を固定する。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class AttendeeListPresenterTests: XCTestCase {

    private func makePresenter(
        names: [String] = [],
        gateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway(),
        featureUnlock: FeatureUnlockState = FeatureUnlockState(),
        rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayBase()
    ) -> AttendeeListPresenter {
        makePresenter(
            names: names,
            interactor: AttendeeListInteractor(favoriteGateway: gateway, featureUnlock: featureUnlock),
            rewardedAd: rewardedAd
        )
    }

    private func makePresenter(
        names: [String] = [],
        interactor: AttendeeListInteractor,
        rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayBase()
    ) -> AttendeeListPresenter {
        if !names.isEmpty {
            _ = interactor.add(fromText: names.joined(separator: ","))
        }
        let presenter = AttendeeListPresenter(
            interactor: interactor,
            router: AttendeeListRouter(rewardedAd: rewardedAd)
        )
        presenter.onAppear()
        return presenter
    }

    private func names(of presenter: AttendeeListPresenter) -> [String] {
        presenter.viewData.rows.map(\.name)
    }

    /// View 経路の unstructured Task が終わるまで待つ。
    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        _ condition: @MainActor () -> Bool
    ) async {
        let started = DispatchTime.now().uptimeNanoseconds
        while !condition() {
            if DispatchTime.now().uptimeNanoseconds - started >= timeoutNanoseconds {
                return
            }
            await Task.yield()
        }
    }

    // MARK: - 参加者 / ViewData

    func test_追加時に前後空白を除去する() {
        let presenter = makePresenter()

        presenter.didTapAdd(name: "  佐藤  ")

        XCTAssertEqual(names(of: presenter), ["佐藤"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1])
        XCTAssertTrue(presenter.viewData.canStartSeating)
        XCTAssertFalse(presenter.viewData.isEmpty)
    }

    func test_initでInteractorの一覧をViewDataに公開する() {
        let presenter = makePresenter(names: ["A", "B"])

        XCTAssertEqual(names(of: presenter), ["A", "B"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2])
    }

    func test_単一削除で指定行だけ消える() {
        let presenter = makePresenter(names: ["A", "B", "C"])

        presenter.didDeleteAttendees(at: IndexSet(integer: 1))

        XCTAssertEqual(names(of: presenter), ["A", "C"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2])
    }

    func test_複数削除はIndexSetを一度だけ適用する() {
        let presenter = makePresenter(names: ["A", "B", "C", "D"])

        presenter.didDeleteAttendees(at: IndexSet([0, 2]))

        XCTAssertEqual(names(of: presenter), ["B", "D"])
    }

    func test_リセットは確認Routeのあと全員削除する() {
        let presenter = makePresenter(names: ["A", "B"])

        presenter.didTapReset()
        XCTAssertEqual(presenter.route, .alert(.confirmReset))
        XCTAssertEqual(names(of: presenter), ["A", "B"])

        presenter.didConfirmReset()

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertFalse(presenter.viewData.canReset)
        XCTAssertNil(presenter.route)
    }

    func test_一括追加の結果をそのまま公開する() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapBulkAdd(text: "A,B")

        XCTAssertEqual(names(of: presenter), ["A", "A(2)", "B"])
        XCTAssertNil(presenter.route)
    }

    // MARK: - Route

    func test_座席表タップでrouteがseatingChartになる() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSeatingChart()

        XCTAssertEqual(presenter.route, .seatingChart)
        XCTAssertTrue(presenter.route?.presentsAsNavigation == true)
    }

    func test_番号札タップでrouteがsimpleShuffleになる() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSimpleShuffle()

        XCTAssertEqual(presenter.route, .simpleShuffle)
        XCTAssertTrue(presenter.route?.presentsAsNavigation == true)
    }

    func test_お気に入り一覧タップでrouteがfavoriteListになる() {
        let presenter = makePresenter()

        presenter.didTapShowFavorites()

        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertTrue(presenter.route?.presentsAsSheet == true)
    }

    func test_一括追加タップでrouteがbulkAddになる() {
        let presenter = makePresenter()

        presenter.didTapBulkAddEntry()

        XCTAssertEqual(presenter.route, .bulkAdd)
        XCTAssertTrue(presenter.route?.presentsAsSheet == true)
    }

    func test_dismissRouteで提示を閉じる() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
        XCTAssertNil(presenter.favoriteGroupPresenter)
    }

    // MARK: - お気に入り

    func test_お気に入り保存が可能ならプロンプトを出す() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSaveFavorite()

        XCTAssertEqual(presenter.route, .saveFavoritePrompt)
        XCTAssertTrue(presenter.route?.presentsAsAlert == true)
    }

    func test_視聴成功なら1回限り保存でき次は再び上限になる() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        await presenter.confirmWatchAd()

        XCTAssertEqual(presenter.route, .saveFavoritePrompt)
        presenter.didConfirmSaveFavorite(name: "追加枠")

        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount + 1)
        XCTAssertNil(presenter.route)
        XCTAssertEqual(fake.presentCallCount, 1)

        presenter.didTapSaveFavorite()
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount + 1,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
    }

    func test_視聴未準備ならアラートになり上限はバイパスしない() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .notReady)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        await presenter.confirmWatchAd()

        XCTAssertEqual(presenter.route, .alert(.adNotReady))
        XCTAssertEqual(fake.presentCallCount, 1)

        presenter.didConfirmSaveFavorite(name: "追加枠")
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
    }

    func test_視聴未獲得と失敗では上限をバイパスしない() async throws {
        for outcome in [RewardedAdGatewayFake.Outcome.notEarned, .failed("network")] {
            let gateway = InMemoryGroupFavoriteGateway()
            let fake = RewardedAdGatewayFake(outcome: outcome)
            let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
            for index in 1...FeatureLimit.freeFavoriteGroupCount {
                presenter.didConfirmSaveFavorite(name: "グループ\(index)")
            }

            await presenter.confirmWatchAd()

            XCTAssertNil(presenter.route, "outcome: \(outcome)")
            presenter.didConfirmSaveFavorite(name: "追加枠")
            XCTAssertEqual(
                presenter.route,
                .alert(.favoriteLimitReached(
                    currentCount: FeatureLimit.freeFavoriteGroupCount,
                    limit: FeatureLimit.freeFavoriteGroupCount
                )),
                "outcome: \(outcome)"
            )
            XCTAssertEqual(
                try gateway.fetchSummaries().count,
                FeatureLimit.freeFavoriteGroupCount,
                "outcome: \(outcome)"
            )
            XCTAssertEqual(fake.presentCallCount, 1, "outcome: \(outcome)")
        }
    }

    func test_確定済み名前は視聴成功後に保存する() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didConfirmSaveFavorite(name: "追加枠")
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )

        await presenter.confirmWatchAd()

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name).first, "追加枠")
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount + 1)
        XCTAssertNil(presenter.route)
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_didConfirmWatchAdはBindingのdismissが先でも確定済み名前で保存する() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didConfirmSaveFavorite(name: "追加枠")
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )

        presenter.dismissRoute()
        presenter.didConfirmWatchAd()

        await waitUntil {
            (try? gateway.fetchSummaries().count) == FeatureLimit.freeFavoriteGroupCount + 1
        }

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name).first, "追加枠")
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount + 1)
        XCTAssertNil(presenter.route)
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_didConfirmWatchAdのView経路は名前未確定ならプロンプトを出す() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didConfirmWatchAd()

        await waitUntil { presenter.route == .saveFavoritePrompt }

        XCTAssertEqual(presenter.route, .saveFavoritePrompt)
        XCTAssertEqual(fake.presentCallCount, 1)
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
    }

    func test_上限アラートのキャンセルは確定済み名前を捨てる() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didConfirmSaveFavorite(name: "追加枠")
        presenter.didCancelFavoriteLimit()

        await presenter.confirmWatchAd()

        XCTAssertEqual(presenter.route, .saveFavoritePrompt)
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
        XCTAssertFalse(try gateway.fetchSummaries().map(\.name).contains("追加枠"))
    }

    func test_保存プロンプトを閉じるとバイパスを取り消す() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: fake)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        await presenter.confirmWatchAd()
        XCTAssertEqual(presenter.route, .saveFavoritePrompt)

        presenter.dismissRoute()

        presenter.didConfirmSaveFavorite(name: "追加枠")
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
    }

    func test_ルートを閉じると広告待ちの許可は破棄される() async throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let hanging = RewardedAdGatewayHangingFake()
        let presenter = makePresenter(names: ["A"], gateway: gateway, rewardedAd: hanging)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didConfirmSaveFavorite(name: "追加枠")
        presenter.didConfirmWatchAd()
        await hanging.waitUntilPresentStarted()
        presenter.dismissRoute()

        await waitUntil { presenter.route == nil }

        XCTAssertNil(presenter.route)
        presenter.didConfirmSaveFavorite(name: "追加枠")
        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
    }

    func test_お気に入りが上限に達するとアラートになる() {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didTapSaveFavorite()

        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
    }

    func test_現在の参加者をお気に入りに保存する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["太郎", "花子"], gateway: gateway)

        presenter.didConfirmSaveFavorite(name: "同期")

        let summaries = try gateway.fetchSummaries()
        XCTAssertEqual(summaries.count, 1)
        let saved = try XCTUnwrap(summaries.first)
        XCTAssertEqual(saved.name, "同期")
        XCTAssertEqual(try gateway.fetch(id: saved.id)?.memberNames, ["太郎", "花子"])
        XCTAssertNil(presenter.route)
    }

    func test_お気に入り選択で参加者リストを置換する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "新メンバ", members: ["新1", "新2", "新3"])
        let presenter = makePresenter(names: ["旧1", "旧2"], gateway: gateway)

        presenter.favoriteGroupDidSelect(id: try XCTUnwrap(gateway.fetchSummaries().first?.id))

        XCTAssertEqual(names(of: presenter), ["新1", "新2", "新3"])
        XCTAssertNil(presenter.route)
    }

    func test_メンバーが空のお気に入りを選ぶとリストが空になる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "空", members: [])
        let presenter = makePresenter(names: ["残したくない"], gateway: gateway)

        presenter.favoriteGroupDidSelect(id: try XCTUnwrap(gateway.fetchSummaries().first?.id))

        XCTAssertTrue(presenter.viewData.isEmpty)
    }

    func test_空白のみのグループ名では保存しない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        presenter.didTapSaveFavorite()

        presenter.didConfirmSaveFavorite(name: "   ")

        XCTAssertTrue(try gateway.fetchSummaries().isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_お気に入り保存失敗はアラートになる() {
        let presenter = makePresenter(names: ["A"], gateway: FailingInsertGroupFavoriteGateway())

        presenter.didConfirmSaveFavorite(name: "同期")

        XCTAssertEqual(
            presenter.route,
            .alert(.saveFailed(message: "書き込みに失敗しました"))
        )
        XCTAssertEqual(names(of: presenter), ["A"])
    }

    func test_存在しないお気に入りを選んでもリストとRouteは変わらない() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapShowFavorites()

        let child = presenter.favoriteGroupPresenter
        presenter.favoriteGroupDidSelect(id: UUID())

        XCTAssertEqual(names(of: presenter), ["A"])
        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertTrue(presenter.favoriteGroupPresenter === child)
    }

    // MARK: - 子モジュール Output（Phase 5）

    func test_FavoriteGroupOutputの選択はリストを置換してシートを閉じる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "新メンバ", members: ["新1", "新2"])
        let presenter = makePresenter(names: ["旧"], gateway: gateway)
        presenter.didTapShowFavorites()

        presenter.favoriteGroupDidSelect(id: try XCTUnwrap(gateway.fetchSummaries().first?.id))

        XCTAssertEqual(names(of: presenter), ["新1", "新2"])
        XCTAssertNil(presenter.route)
        XCTAssertNil(presenter.favoriteGroupPresenter)
    }

    func test_FavoriteGroupOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()

        presenter.favoriteGroupDidCancel()

        XCTAssertNil(presenter.route)
        XCTAssertNil(presenter.favoriteGroupPresenter)
    }

    func test_お気に入りシートは親と同じGatewayインスタンスで組み立てる() throws {
        let gateway = FetchCountingGroupFavoriteGateway()
        try gateway.insert(name: "共有", members: ["A"])
        let presenter = makePresenter(gateway: gateway)
        let fetchCountBeforeSheet = gateway.fetchSummariesCallCount

        presenter.didTapShowFavorites()
        _ = presenter.makeRouteSheet(.favoriteList)

        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertGreaterThan(gateway.fetchSummariesCallCount, fetchCountBeforeSheet)
    }

    func test_BulkAddOutputの確定は一括追加してシートを閉じる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapBulkAddEntry()

        presenter.bulkAddDidConfirm(text: "B,C")

        XCTAssertEqual(names(of: presenter), ["A", "B", "C"])
        XCTAssertNil(presenter.route)
    }

    func test_BulkAddOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter()
        presenter.didTapBulkAddEntry()

        presenter.bulkAddDidCancel()

        XCTAssertNil(presenter.route)
    }

    // MARK: - シート identity（Phase 4）

    func test_お気に入りシート期間中は同一の子Presenterを返す() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()
        let first = presenter.favoriteGroupPresenter
        XCTAssertNotNil(first)

        _ = presenter.makeRouteSheet(.favoriteList)
        XCTAssertTrue(presenter.favoriteGroupPresenter === first)
        _ = presenter.makeRouteSheet(.favoriteList)
        XCTAssertTrue(presenter.favoriteGroupPresenter === first)
    }

    func test_お気に入りシートを閉じたら子Presenterを破棄し再表示で新規assembleする() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()
        let first = presenter.favoriteGroupPresenter
        XCTAssertNotNil(first)

        presenter.dismissRoute()
        XCTAssertNil(presenter.favoriteGroupPresenter)

        presenter.didTapShowFavorites()
        let second = presenter.favoriteGroupPresenter
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }

    func test_シート再組み立てでも子のrouteが消えない() throws {
        let presenter = makePresenter(gateway: FailingFetchGroupFavoriteGateway())
        presenter.didTapShowFavorites()
        let child = try XCTUnwrap(presenter.favoriteGroupPresenter)
        XCTAssertEqual(
            child.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )

        _ = presenter.makeRouteSheet(.favoriteList)
        _ = presenter.makeRouteSheet(.favoriteList)

        XCTAssertTrue(presenter.favoriteGroupPresenter === child)
        XCTAssertEqual(
            child.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )
    }

    func test_お気に入りシートを閉じたあとGateway差し替えで新しい子が読む() throws {
        let firstGateway = InMemoryGroupFavoriteGateway()
        try firstGateway.insert(name: "最初", members: ["A"])
        let interactor = AttendeeListInteractor(favoriteGateway: firstGateway)
        let presenter = makePresenter(interactor: interactor)
        presenter.didTapShowFavorites()
        XCTAssertEqual(presenter.favoriteGroupPresenter?.viewData.rows.map(\.name), ["最初"])
        presenter.dismissRoute()

        let secondGateway = InMemoryGroupFavoriteGateway()
        try secondGateway.insert(name: "差し替え後", members: ["B"])
        interactor.attachFavoriteGateway(secondGateway)
        presenter.didTapShowFavorites()

        XCTAssertEqual(presenter.favoriteGroupPresenter?.viewData.rows.map(\.name), ["差し替え後"])
    }

    // MARK: - 人数上限（v2.1）

    private func numberedNames(_ count: Int, prefix: String = "P") -> [String] {
        (1...count).map { "\(prefix)\($0)" }
    }

    func test_40人で未解放の追加は解放ダイアログになり名前は入らない() {
        let presenter = makePresenter(names: numberedNames(FeatureLimit.freeAttendeeCount))

        XCTAssertEqual(presenter.viewData.addControl, .needsUnlock)
        let accepted = presenter.didTapAdd(name: "41人目")

        XCTAssertFalse(accepted)
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.freeAttendeeCount)
        XCTAssertEqual(
            presenter.route,
            .alert(.attendeeUnlock(overflowTotal: nil, remainingFree: nil, remainingHard: nil))
        )
    }

    func test_人数解放の視聴成功で待っていた名前が入る() async {
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: unlock,
            rewardedAd: fake
        )
        _ = presenter.didTapAdd(name: "41人目")

        await presenter.confirmWatchVenueAd()

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertTrue(names(of: presenter).contains("41人目"))
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.freeAttendeeCount + 1)
        XCTAssertEqual(presenter.viewData.addControl, .available)
        XCTAssertNil(presenter.route)
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_人数解放の視聴失敗では名前もフラグも動かない() async {
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .notEarned)
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: unlock,
            rewardedAd: fake
        )
        _ = presenter.didTapAdd(name: "41人目")

        await presenter.confirmWatchVenueAd()

        XCTAssertFalse(unlock.isSessionUnlocked)
        XCTAssertFalse(names(of: presenter).contains("41人目"))
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_120人の次はハード上限でpresentしない() async {
        let unlock = FeatureUnlockState(isSessionUnlocked: true)
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.maxAttendeeCount),
            featureUnlock: unlock,
            rewardedAd: fake
        )

        XCTAssertEqual(presenter.viewData.addControl, .hardLimited)
        _ = presenter.didTapAdd(name: "121人目")

        XCTAssertEqual(presenter.route, .alert(.attendeeHardLimit))
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.maxAttendeeCount)
        XCTAssertEqual(fake.presentCallCount, 0)
    }

    func test_120人でもお気に入り一覧は開く() {
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.maxAttendeeCount),
            featureUnlock: FeatureUnlockState(isSessionUnlocked: true)
        )

        presenter.didTapShowFavorites()

        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertNotNil(presenter.favoriteGroupPresenter)
    }

    func test_120人では一括入力は開かずハード上限になる() {
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.maxAttendeeCount),
            featureUnlock: FeatureUnlockState(isSessionUnlocked: true)
        )

        presenter.didTapBulkAddEntry()

        XCTAssertEqual(presenter.route, .alert(.attendeeHardLimit))
    }

    func test_溢れ文言は無料枠と絶対上限で出し分ける() {
        XCTAssertEqual(
            VenueExpansionCopy.attendeeOverflowMessage(triedCount: 2, remainingFree: 1, remainingHard: 81),
            "2人のうち、1人までは無料で追加できます。動画を1本見ると、残りもすべて追加されます。"
        )
        XCTAssertEqual(
            VenueExpansionCopy.attendeeOverflowMessage(triedCount: 90, remainingFree: 1, remainingHard: 81),
            "90人のうち、1人までは無料で追加できます。動画を1本見ると、上限（\(FeatureLimit.maxAttendeeCount)人）まで追加されます。"
        )
        XCTAssertEqual(
            VenueExpansionCopy.attendeeOverflowMessage(triedCount: 20, remainingFree: 0, remainingHard: 80),
            "無料枠（\(FeatureLimit.freeAttendeeCount)人）を使い切っています。動画を1本見ると、追加しようとする全員を登録できます。"
        )
        XCTAssertEqual(
            VenueExpansionCopy.attendeeOverflowMessage(triedCount: 81, remainingFree: 0, remainingHard: 80),
            "無料枠（\(FeatureLimit.freeAttendeeCount)人）を使い切っています。動画を1本見ると、上限（\(FeatureLimit.maxAttendeeCount)人）まで追加できます。"
        )
        XCTAssertEqual(
            VenueExpansionCopy.attendeeHardLimitOverflowMessage(triedCount: 3, remainingHard: 2),
            "3人のうち、2人まで追加できます。上限（\(FeatureLimit.maxAttendeeCount)人）を超える分は追加できません。"
        )
    }

    func test_解放後に上限を跨ぐ一括追加は入れる人数を案内する() {
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.maxAttendeeCount - 2),
            featureUnlock: FeatureUnlockState(isSessionUnlocked: true)
        )

        presenter.didTapBulkAdd(text: "余り1,余り2,余り3")

        XCTAssertEqual(names(of: presenter).count, FeatureLimit.maxAttendeeCount)
        XCTAssertTrue(names(of: presenter).contains("余り1"))
        XCTAssertTrue(names(of: presenter).contains("余り2"))
        XCTAssertFalse(names(of: presenter).contains("余り3"))
        XCTAssertEqual(
            presenter.route,
            .alert(.attendeeHardLimitOverflow(triedCount: 3, remainingHard: 2))
        )
    }

    func test_一括追加で無料枠に一部入ったときは残り無料人数を案内する() {
        let presenter = makePresenter(names: numberedNames(FeatureLimit.freeAttendeeCount - 1))

        presenter.didTapBulkAdd(text: "余り1,余り2")

        XCTAssertEqual(names(of: presenter).count, FeatureLimit.freeAttendeeCount)
        XCTAssertTrue(names(of: presenter).contains("余り1"))
        XCTAssertFalse(names(of: presenter).contains("余り2"))
        XCTAssertEqual(
            presenter.route,
            .alert(.attendeeUnlock(overflowTotal: 2, remainingFree: 1, remainingHard: 81))
        )
    }

    func test_上限を超える一括追加は視聴後に120人まで入りハード上限アラートは出さない() async {
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: unlock,
            rewardedAd: fake
        )
        let overflowCount = FeatureLimit.maxAttendeeCount - FeatureLimit.freeAttendeeCount + 1
        let overflowNames = numberedNames(overflowCount, prefix: "追加")

        presenter.didTapBulkAdd(text: overflowNames.joined(separator: ","))

        XCTAssertEqual(
            presenter.route,
            .alert(.attendeeUnlock(
                overflowTotal: overflowCount,
                remainingFree: 0,
                remainingHard: FeatureLimit.maxAttendeeCount - FeatureLimit.freeAttendeeCount
            ))
        )

        await presenter.confirmWatchVenueAd()

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.maxAttendeeCount)
        XCTAssertTrue(names(of: presenter).contains("追加1"))
        XCTAssertFalse(names(of: presenter).contains("追加\(overflowCount)"))
        XCTAssertNil(presenter.route)
    }

    func test_一括追加の溢れは視聴成功後に入り失敗後は残る() async {
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: unlock,
            rewardedAd: fake
        )

        presenter.didTapBulkAdd(text: "余り1,余り2")

        XCTAssertEqual(
            presenter.route,
            .alert(.attendeeUnlock(overflowTotal: 2, remainingFree: 0, remainingHard: 80))
        )
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.freeAttendeeCount)

        await presenter.confirmWatchVenueAd()

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertTrue(names(of: presenter).contains("余り1"))
        XCTAssertTrue(names(of: presenter).contains("余り2"))
        XCTAssertEqual(names(of: presenter).count, FeatureLimit.freeAttendeeCount + 2)

        let racedUnlock = FeatureUnlockState()
        let racedFake = RewardedAdGatewayFake(outcome: .success)
        let raced = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: racedUnlock,
            rewardedAd: racedFake
        )
        raced.didTapBulkAdd(text: "競合1,競合2")
        raced.dismissRoute()
        await raced.confirmWatchVenueAd()
        XCTAssertTrue(racedUnlock.isSessionUnlocked)
        XCTAssertTrue(names(of: raced).contains("競合1"))
        XCTAssertTrue(names(of: raced).contains("競合2"))

        let failedUnlock = FeatureUnlockState()
        let failedFake = RewardedAdGatewayFake(outcome: .failed("network"))
        let failed = makePresenter(
            names: numberedNames(FeatureLimit.freeAttendeeCount),
            featureUnlock: failedUnlock,
            rewardedAd: failedFake
        )
        failed.didTapBulkAdd(text: "残りA,残りB")
        await failed.confirmWatchVenueAd()

        XCTAssertFalse(failedUnlock.isSessionUnlocked)
        XCTAssertFalse(names(of: failed).contains("残りA"))
        XCTAssertEqual(failedFake.presentCallCount, 1)
    }

    func test_会場拡張フラグではお気に入り4枠目は保存できない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let unlock = FeatureUnlockState(isSessionUnlocked: true)
        let presenter = makePresenter(names: ["A"], gateway: gateway, featureUnlock: unlock)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didTapSaveFavorite()

        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
        XCTAssertEqual(try gateway.fetchSummaries().count, FeatureLimit.freeFavoriteGroupCount)
    }
}
