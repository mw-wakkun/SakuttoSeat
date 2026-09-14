//
//  AdsPhase0Tests.swift
//  SakuttoSeatTests
//
//  refactor_Ad.md Phase 0
//  バナー再 load 判断・リワード契約・エラー型を現行挙動のまま固定する。
//  refactor_Ad.md Phase 1（AdConfiguration / UnlockRequirement の移設を固定）
//  refactor_Ad.md Phase 2（Router が Fake を注入できることを固定）
//  refactor_Ad.md Phase 3（報酬フラグの順序・バナー幅の pt 丸め）
//  refactor_Ad.md Phase 4（未準備アラート文言の単一化。Presenter 分岐は Share / VenueSettings テスト）
//  refactor_Ad.md Phase 5（バナー余白トークンとプレースホルダ高さ。Representable は fileprivate）
//  refactor_Ad.md Phase 6（非表示時は mount しない。SKAdNetwork 拡充。ATT は出さない）
//

import StoreKit
import XCTest
@testable import SakuttoSeat

// MARK: - バナー再 load 判断

final class AdBannerReloadPolicyTests: XCTestCase {

    func test_初回は再loadする() {
        XCTAssertTrue(
            AdBannerMetrics.shouldReloadBanner(
                previous: nil,
                next: CGSize(width: 320, height: 50)
            )
        )
    }

    func test_同じサイズなら再loadしない() {
        let size = CGSize(width: 320, height: 50)

        XCTAssertFalse(AdBannerMetrics.shouldReloadBanner(previous: size, next: size))
    }

    func test_サイズが変わったら再loadする() {
        XCTAssertTrue(
            AdBannerMetrics.shouldReloadBanner(
                previous: CGSize(width: 320, height: 50),
                next: CGSize(width: 390, height: 60)
            )
        )
    }

    func test_幅をpt単位で丸めて同じなら再loadしない() {
        XCTAssertFalse(
            AdBannerMetrics.shouldReloadBanner(
                previous: CGSize(width: 320.4, height: 50.2),
                next: CGSize(width: 320.1, height: 50.4)
            )
        )
    }

    func test_丸めた幅が違えば再loadする() {
        XCTAssertTrue(
            AdBannerMetrics.shouldReloadBanner(
                previous: CGSize(width: 320.4, height: 50),
                next: CGSize(width: 320.6, height: 50)
            )
        )
    }
}

// MARK: - 非表示時は Representable を載せない（Phase 6）

final class AdBannerVisibilityTests: XCTestCase {

    func test_画面上で幅が確定していれば載せる() {
        XCTAssertTrue(AdBannerMetrics.shouldMountBanner(isOnScreen: true, width: 390))
    }

    func test_Navigationで隠れた画面は載せない() {
        XCTAssertFalse(AdBannerMetrics.shouldMountBanner(isOnScreen: false, width: 390))
    }

    func test_幅未確定では載せない() {
        XCTAssertFalse(AdBannerMetrics.shouldMountBanner(isOnScreen: true, width: 0))
        XCTAssertFalse(AdBannerMetrics.shouldMountBanner(isOnScreen: false, width: 0))
    }
}

// MARK: - バナー余白・プレースホルダ（Phase 5。Container 内に閉じる）

final class AdBannerChromeTests: XCTestCase {

    func test_幅未確定時のプレースホルダ高さはジャンプを避ける() {
        XCTAssertEqual(AppSpacing.bannerFallbackHeight, 50)
    }

    func test_上下余白は同一トークン() {
        XCTAssertEqual(AppSpacing.bannerVerticalPadding, 4)
    }
}

// MARK: - AdConfiguration（Phase 1。DEBUG / TestFlight は Google サンプル ID）

final class AdConfigurationTests: XCTestCase {

    func test_サンプルと本番のユニットID定数を固定する() {
        XCTAssertEqual(
            AdConfiguration.googleSampleBannerUnitID,
            "ca-app-pub-3940256099942544/2934735716"
        )
        XCTAssertEqual(
            AdConfiguration.googleSampleRewardedUnitID,
            "ca-app-pub-3940256099942544/5224354917"
        )
        XCTAssertEqual(
            AdConfiguration.productionBannerUnitID,
            "ca-app-pub-9676260030977388/3254679876"
        )
        XCTAssertEqual(
            AdConfiguration.productionRewardedUnitID,
            "ca-app-pub-9676260030977388/5413826350"
        )
    }

    func test_DEBUGビルドは配信環境に関係なくテスト広告() {
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: true,
                distribution: .appStoreProduction
            )
        )
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: true,
                distribution: .testFlightOrUnknown
            )
        )
    }

    func test_ReleaseのTestFlightはテスト広告() {
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: false,
                distribution: .testFlightOrUnknown
            )
        )
    }

    func test_ReleaseのAppStoreは本番広告() {
        XCTAssertFalse(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: false,
                distribution: .appStoreProduction
            )
        )
    }

    func test_StoreKitのproductionだけ本番配信とみなす() {
        XCTAssertEqual(
            AdConfiguration.distribution(from: .production),
            .appStoreProduction
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: .sandbox),
            .testFlightOrUnknown
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: .xcode),
            .testFlightOrUnknown
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: nil),
            .testFlightOrUnknown
        )
    }

    func test_解決したユニットIDは判定結果に一致する() async {
        let usesTestAdUnits = await AdConfiguration.resolvedUsesTestAdUnits()
        let bannerUnitID = await AdConfiguration.resolvedBannerUnitID()
        let rewardedUnitID = await AdConfiguration.resolvedRewardedUnitID()
        if usesTestAdUnits {
            XCTAssertEqual(bannerUnitID, AdConfiguration.googleSampleBannerUnitID)
            XCTAssertEqual(rewardedUnitID, AdConfiguration.googleSampleRewardedUnitID)
        } else {
            XCTAssertEqual(bannerUnitID, AdConfiguration.productionBannerUnitID)
            XCTAssertEqual(rewardedUnitID, AdConfiguration.productionRewardedUnitID)
        }
    }
}

// MARK: - UnlockRequirement（Core Entity）

final class UnlockRequirementTests: XCTestCase {

    func test_同等比較できる() {
        XCTAssertEqual(UnlockRequirement.none, .none)
        XCTAssertEqual(UnlockRequirement.rewardedAd, .rewardedAd)
        XCTAssertNotEqual(UnlockRequirement.none, .rewardedAd)
    }
}

// MARK: - RewardedAdError（Core Entity）

final class RewardedAdErrorTests: XCTestCase {

    func test_同等比較できる() {
        XCTAssertEqual(RewardedAdError.notReady, .notReady)
        XCTAssertEqual(RewardedAdError.notEarned, .notEarned)
        XCTAssertEqual(RewardedAdError.failed("x"), .failed("x"))
        XCTAssertNotEqual(RewardedAdError.failed("x"), .failed("y"))
        XCTAssertNotEqual(RewardedAdError.notReady, .notEarned)
    }
}

// MARK: - 未準備アラート文言（Phase 4。Share / VenueSettings で同一）

final class RewardedAdCopyTests: XCTestCase {

    func test_未準備のタイトルと本文は計画どおり() {
        XCTAssertEqual(RewardedAdCopy.notReadyTitle, "広告の準備ができていません")
        XCTAssertEqual(
            RewardedAdCopy.notReadyMessage,
            "広告の準備ができていません。しばらく待ってからもう一度お試しください。"
        )
    }
}

// MARK: - Gateway Fake（契約の固定）

@MainActor
final class RewardedAdGatewayFakeTests: XCTestCase {

    func test_preloadは呼び出し回数を数え準備済みにする() {
        let fake = RewardedAdGatewayFake(isReady: false, outcome: .success)

        fake.preload()

        XCTAssertEqual(fake.preloadCallCount, 1)
        XCTAssertTrue(fake.isReady)
    }

    func test_preloadはnotReadyのとき準備済みにしない() {
        let fake = RewardedAdGatewayFake(isReady: false, outcome: .notReady)

        fake.preload()

        XCTAssertEqual(fake.preloadCallCount, 1)
        XCTAssertFalse(fake.isReady)
    }

    func test_成功はthrowしない() async throws {
        let fake = RewardedAdGatewayFake(outcome: .success)

        try await fake.present()

        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_未準備はnotReadyを投げる() async {
        let fake = RewardedAdGatewayFake(outcome: .notReady)

        await assertThrown(fake, equals: .notReady)
    }

    func test_未獲得はnotEarnedを投げる() async {
        let fake = RewardedAdGatewayFake(outcome: .notEarned)

        await assertThrown(fake, equals: .notEarned)
    }

    func test_失敗はfailedを投げる() async {
        let fake = RewardedAdGatewayFake(outcome: .failed("network"))

        await assertThrown(fake, equals: .failed("network"))
    }

    func test_提示中の再入は現行Managerと同じfailed文言() async {
        let fake = RewardedAdGatewayFake(outcome: .alreadyPresenting)

        await assertThrown(fake, equals: .failed("すでに広告を提示中です"))
    }

    private func assertThrown(_ fake: RewardedAdGatewayFake, equals expected: RewardedAdError) async {
        do {
            try await fake.present()
            XCTFail("expected \(expected)")
        } catch let error as RewardedAdError {
            XCTAssertEqual(error, expected)
            XCTAssertEqual(fake.presentCallCount, 1)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

// MARK: - 報酬フラグの順序（Phase 3。SDK なしでコールバック順を駆動）

final class RewardedAdPresentationStateTests: XCTestCase {

    func test_同期で報酬を立ててからdismissするとearned() {
        var state = RewardedAdPresentationState()

        XCTAssertTrue(state.beginPresenting())
        state.markEarned()

        XCTAssertEqual(state.dismiss(), .earned)
        XCTAssertFalse(state.isPresenting)
        XCTAssertFalse(state.hasEarnedReward)
    }

    func test_報酬なしでdismissするとnotEarned() {
        var state = RewardedAdPresentationState()

        XCTAssertTrue(state.beginPresenting())

        XCTAssertEqual(state.dismiss(), .notEarned)
    }

    func test_dismiss後の遅延markEarnedは覆さない() {
        var state = RewardedAdPresentationState()
        XCTAssertTrue(state.beginPresenting())

        XCTAssertEqual(state.dismiss(), .notEarned)
        state.markEarned()

        XCTAssertEqual(state.dismiss(), .alreadyFinished)
        XCTAssertFalse(state.hasEarnedReward)
    }

    func test_failするとfailed() {
        var state = RewardedAdPresentationState()
        XCTAssertTrue(state.beginPresenting())

        XCTAssertEqual(state.fail("network"), .failed("network"))
        XCTAssertEqual(state.dismiss(), .alreadyFinished)
    }

    func test_二重dismissはalreadyFinished() {
        var state = RewardedAdPresentationState()
        XCTAssertTrue(state.beginPresenting())
        state.markEarned()

        XCTAssertEqual(state.dismiss(), .earned)
        XCTAssertEqual(state.dismiss(), .alreadyFinished)
    }

    func test_提示中の再beginはfalse() {
        var state = RewardedAdPresentationState()

        XCTAssertTrue(state.beginPresenting())
        XCTAssertFalse(state.beginPresenting())
    }

    func test_未dismissの破棄はfailed() {
        var state = RewardedAdPresentationState()
        XCTAssertTrue(state.beginPresenting())

        XCTAssertEqual(state.abortIfPresenting(), .failed("広告の提示が中断されました"))
        XCTAssertFalse(state.isPresenting)
    }

    func test_提示していないabortはalreadyFinished() {
        var state = RewardedAdPresentationState()

        XCTAssertEqual(state.abortIfPresenting(), .alreadyFinished)
    }

    func test_完了後に再beginできる() {
        var state = RewardedAdPresentationState()
        XCTAssertTrue(state.beginPresenting())
        state.markEarned()
        XCTAssertEqual(state.dismiss(), .earned)

        XCTAssertTrue(state.beginPresenting())
        XCTAssertFalse(state.hasEarnedReward)
        XCTAssertEqual(state.dismiss(), .notEarned)
    }
}

// MARK: - SKAdNetwork / ATT（Phase 6。収益まわりの仕様固定）

final class AdPrivacyConfigurationTests: XCTestCase {

    func test_SKAdNetworkはGoogle公式識別子を含み1件だけではない() {
        let identifiers = skAdNetworkIdentifiers()

        XCTAssertTrue(
            identifiers.contains("cstr6suwn9.skadnetwork"),
            "Google 公式の cstr6suwn9.skadnetwork が必要"
        )
        // Google AdMob quick-start（2026-09-11）は 50 件。1 件への回帰を防ぐ。
        XCTAssertGreaterThanOrEqual(identifiers.count, 50)
        XCTAssertEqual(identifiers.count, Set(identifiers).count, "重複があってはならない")
        XCTAssertTrue(identifiers.allSatisfy { $0.hasSuffix(".skadnetwork") })
    }

    func test_ATTは出さないのでUsageDescriptionを持たない() {
        let description = appInfoDictionary()["NSUserTrackingUsageDescription"]
        XCTAssertNil(description)
    }

    private func skAdNetworkIdentifiers() -> [String] {
        let items = appInfoDictionary()["SKAdNetworkItems"] as? [[String: String]] ?? []
        return items.compactMap { $0["SKAdNetworkIdentifier"] }
    }

    private func appInfoDictionary() -> [String: Any] {
        Bundle(for: RewardedAdGatewayImpl.self).infoDictionary ?? [:]
    }
}

