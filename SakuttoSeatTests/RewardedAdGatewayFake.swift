//
//  RewardedAdGatewayFake.swift
//  SakuttoSeatTests
//
//  refactor_Ad.md Phase 0（Gateway 契約のテストダブル。Router 注入は Phase 2）
//

@testable import SakuttoSeat
import Foundation

/// Share / VenueSettings の提示経路を、SDK なしで固定するための Fake。
/// Phase 2 で Router が Gateway を受け取るまで、Presenter 結合テストは XCTSkip する。
nonisolated final class RewardedAdGatewayFake: RewardedAdGateway, RewardedAdPresenting {
    enum Outcome: Equatable {
        case success
        case notReady
        case notEarned
        case failed(String)
        case alreadyPresenting
    }

    private(set) var isReady: Bool
    private(set) var preloadCallCount = 0
    private(set) var presentCallCount = 0
    var outcome: Outcome

    init(isReady: Bool = true, outcome: Outcome = .success) {
        self.isReady = isReady
        self.outcome = outcome
    }

    func preload() {
        preloadCallCount += 1
        if outcome != .notReady {
            isReady = true
        }
    }

    @MainActor
    func present() async throws {
        presentCallCount += 1
        switch outcome {
        case .success:
            return
        case .notReady:
            throw RewardedAdError.notReady
        case .notEarned:
            throw RewardedAdError.notEarned
        case .failed(let message):
            throw RewardedAdError.failed(message)
        case .alreadyPresenting:
            throw RewardedAdError.failed("すでに広告を提示中です")
        }
    }
}
