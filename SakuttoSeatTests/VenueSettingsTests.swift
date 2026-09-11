//
//  VenueSettingsTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 5（VenueSettings 子モジュールの回帰）
//
//  Phase 4 まで SettingsSheetView.applySelection() が持っていた列数の課金ルールを
//  Interactor へ移送したため、規則はここで固定する。
//  refactor_Ad.md Phase 2（Router へ Gateway を注入。Presenter 分岐のケース追加は Phase 4）
//  refactor_Ad.md Phase 4（Fake Gateway で成功 / 未準備 / 未獲得・失敗を固定）
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class VenueSettingsInteractorTests: XCTestCase {

    func test_無料枠以内なら広告不要で適用できる() {
        let interactor = VenueSettingsInteractor(currentColumnCount: 1, featureUnlock: FeatureUnlockState())

        interactor.select(FeatureLimit.freeColumnCount)

        XCTAssertEqual(interactor.applyRequirement(), .none)
    }

    func test_無料枠を超えると未解放なら広告が必要() {
        let interactor = VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: FeatureUnlockState())

        interactor.select(FeatureLimit.freeColumnCount + 1)

        XCTAssertEqual(interactor.applyRequirement(), .rewardedAd)
    }

    func test_セッション解放済みなら無料枠を超えても広告不要() {
        let unlock = FeatureUnlockState(isSessionUnlocked: true)
        let interactor = VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: unlock)

        interactor.select(10)

        XCTAssertEqual(interactor.applyRequirement(), .none)
    }

    func test_解放は共有のGatewayへ書き込まれる() {
        let unlock = FeatureUnlockState()
        let interactor = VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: unlock)

        interactor.grantSessionUnlock()

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertTrue(interactor.isSessionUnlocked)
    }

    func test_選択値は1から10の範囲に収まる() {
        let interactor = VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: FeatureUnlockState())

        XCTAssertEqual(interactor.select(0), 1)
        XCTAssertEqual(interactor.select(99), 10)
    }

    func test_初期値も範囲に収まる() {
        let interactor = VenueSettingsInteractor(currentColumnCount: 42, featureUnlock: FeatureUnlockState())

        XCTAssertEqual(interactor.selectedColumnCount, 10)
    }
}

// MARK: - Presenter

@MainActor
final class VenueSettingsPresenterTests: XCTestCase {

    private final class OutputSpy: VenueSettingsModuleOutput {
        var applied: [Int] = []
        func venueSettingsDidApply(columnCount: Int) { applied.append(columnCount) }
    }

    private func makePresenter(
        currentColumnCount: Int = 2,
        featureUnlock: FeatureUnlockState = FeatureUnlockState(),
        rewardedAd: RewardedAdGatewayBase = RewardedAdGatewayFake(),
        output: OutputSpy
    ) -> VenueSettingsPresenter {
        VenueSettingsPresenter(
            interactor: VenueSettingsInteractor(
                currentColumnCount: currentColumnCount,
                featureUnlock: featureUnlock
            ),
            router: VenueSettingsRouter(rewardedAd: rewardedAd),
            output: output
        )
    }

    func test_無料枠以内の適用はそのままOutputへ渡る() {
        let output = OutputSpy()
        let presenter = makePresenter(output: output)

        presenter.didChangeSelection(1)
        presenter.didTapApply()

        XCTAssertEqual(output.applied, [1])
        XCTAssertNil(presenter.route)
    }

    func test_無料枠を超える適用は解放アラートになりOutputは呼ばれない() {
        let output = OutputSpy()
        let presenter = makePresenter(output: output)

        presenter.didChangeSelection(FeatureLimit.freeColumnCount + 1)
        presenter.didTapApply()

        XCTAssertEqual(presenter.route, .requireUnlock(requested: FeatureLimit.freeColumnCount + 1))
        XCTAssertTrue(output.applied.isEmpty)
    }

    func test_解放済みなら無料枠を超えてもそのまま適用できる() {
        let output = OutputSpy()
        let presenter = makePresenter(featureUnlock: FeatureUnlockState(isSessionUnlocked: true), output: output)

        presenter.didChangeSelection(5)
        presenter.didTapApply()

        XCTAssertEqual(output.applied, [5])
        XCTAssertNil(presenter.route)
    }

    func test_ViewDataは選択値と解放要否を公開する() {
        let output = OutputSpy()
        let presenter = makePresenter(output: output)

        presenter.didChangeSelection(FeatureLimit.freeColumnCount + 1)

        XCTAssertEqual(presenter.viewData.selectedColumnCount, FeatureLimit.freeColumnCount + 1)
        XCTAssertEqual(presenter.viewData.selectableRange, 1...10)
        XCTAssertTrue(presenter.viewData.requiresUnlock)

        presenter.didChangeSelection(FeatureLimit.freeColumnCount)
        XCTAssertFalse(presenter.viewData.requiresUnlock)
    }

    // MARK: - リワード提示（Phase 4）

    func test_視聴確認_成功ならセッション解放して適用する() async {
        let output = OutputSpy()
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .success)
        let presenter = makePresenter(featureUnlock: unlock, rewardedAd: fake, output: output)
        let requested = FeatureLimit.freeColumnCount + 1
        presenter.didChangeSelection(requested)

        await presenter.confirmWatchAd(requestedColumnCount: requested)

        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertEqual(output.applied, [requested])
        XCTAssertNil(presenter.route)
        XCTAssertFalse(presenter.viewData.requiresUnlock)
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_視聴確認_未準備ならアラートになり適用しない() async {
        let output = OutputSpy()
        let unlock = FeatureUnlockState()
        let fake = RewardedAdGatewayFake(outcome: .notReady)
        let presenter = makePresenter(featureUnlock: unlock, rewardedAd: fake, output: output)
        presenter.didChangeSelection(FeatureLimit.freeColumnCount + 1)

        await presenter.confirmWatchAd(requestedColumnCount: presenter.viewData.selectedColumnCount)

        XCTAssertEqual(presenter.route, .adNotReady)
        XCTAssertTrue(output.applied.isEmpty)
        XCTAssertFalse(unlock.isSessionUnlocked)
        XCTAssertTrue(presenter.viewData.requiresUnlock)
        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_視聴確認_未獲得と失敗では解放しない() async {
        for outcome in [RewardedAdGatewayFake.Outcome.notEarned, .failed("network")] {
            let output = OutputSpy()
            let unlock = FeatureUnlockState()
            let fake = RewardedAdGatewayFake(outcome: outcome)
            let presenter = makePresenter(featureUnlock: unlock, rewardedAd: fake, output: output)
            presenter.didChangeSelection(FeatureLimit.freeColumnCount + 1)

            await presenter.confirmWatchAd(requestedColumnCount: presenter.viewData.selectedColumnCount)

            XCTAssertNil(presenter.route, "outcome: \(outcome)")
            XCTAssertTrue(output.applied.isEmpty, "outcome: \(outcome)")
            XCTAssertFalse(unlock.isSessionUnlocked, "outcome: \(outcome)")
            XCTAssertTrue(presenter.viewData.requiresUnlock, "outcome: \(outcome)")
            XCTAssertEqual(fake.presentCallCount, 1, "outcome: \(outcome)")
        }
    }

    func test_ルートを閉じると広告待ちの解放は破棄される() async {
        let output = OutputSpy()
        let unlock = FeatureUnlockState()
        let hanging = RewardedAdGatewayHangingFake()
        let presenter = makePresenter(featureUnlock: unlock, rewardedAd: hanging, output: output)
        presenter.didChangeSelection(FeatureLimit.freeColumnCount + 1)
        let requested = presenter.viewData.selectedColumnCount

        let task = Task { @MainActor in
            await presenter.confirmWatchAd(requestedColumnCount: requested)
        }
        await hanging.waitUntilPresentStarted()
        presenter.dismissRoute()
        hanging.finishSuccessfully()
        await task.value

        XCTAssertNil(presenter.route)
        XCTAssertTrue(output.applied.isEmpty)
        XCTAssertFalse(unlock.isSessionUnlocked)
        XCTAssertTrue(presenter.viewData.requiresUnlock)
    }
}

// MARK: - Router（Gateway 注入）

@MainActor
final class VenueSettingsRouterTests: XCTestCase {

    func test_presentRewardedAdは注入したGatewayを1回呼ぶ() async throws {
        let fake = RewardedAdGatewayFake(outcome: .success)
        let router = VenueSettingsRouter(rewardedAd: fake)

        try await router.presentRewardedAd()

        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_presentRewardedAdはFakeのnotReadyを再throwする() async {
        let fake = RewardedAdGatewayFake(outcome: .notReady)
        let router = VenueSettingsRouter(rewardedAd: fake)

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
