//
//  AdsPhase0Tests.swift
//  SakuttoSeatTests
//
//  refactor_Ad.md Phase 0
//  バナー再 load 判断・リワード契約・エラー型を現行挙動のまま固定する。
//  Share / VenueSettings の提示経路は Router 注入（Phase 2）まで XCTSkip。
//

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
}

// MARK: - RewardedAdError（現行 Entity）

final class RewardedAdErrorTests: XCTestCase {

    func test_同等比較できる() {
        XCTAssertEqual(RewardedAdError.notReady, .notReady)
        XCTAssertEqual(RewardedAdError.notEarned, .notEarned)
        XCTAssertEqual(RewardedAdError.failed("x"), .failed("x"))
        XCTAssertNotEqual(RewardedAdError.failed("x"), .failed("y"))
        XCTAssertNotEqual(RewardedAdError.notReady, .notEarned)
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
