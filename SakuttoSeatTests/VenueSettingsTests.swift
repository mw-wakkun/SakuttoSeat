//
//  VenueSettingsTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 5（VenueSettings 子モジュールの回帰）
//
//  Phase 4 まで SettingsSheetView.applySelection() が持っていた列数の課金ルールを
//  Interactor へ移送したため、規則はここで固定する。
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
        output: OutputSpy
    ) -> VenueSettingsPresenter {
        VenueSettingsPresenter(
            interactor: VenueSettingsInteractor(
                currentColumnCount: currentColumnCount,
                featureUnlock: featureUnlock
            ),
            router: VenueSettingsRouter(),
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
}
