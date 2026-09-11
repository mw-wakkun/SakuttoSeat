//
//  RewardedAdGatewayFake.swift
//  SakuttoSeatTests
//
//  refactor_Ad.md Phase 0（Gateway 契約のテストダブル）
//  refactor_Ad.md Phase 2（RewardedAdGatewayBase を継承し Router へ注入する）
//

@testable import SakuttoSeat
import Foundation

/// Share / VenueSettings の提示経路を、SDK なしで固定するための Fake。
nonisolated final class RewardedAdGatewayFake: RewardedAdGatewayBase {
    enum Outcome: Equatable {
        case success
        case notReady
        case notEarned
        case failed(String)
        case alreadyPresenting
    }

    private(set) var preloadCallCount = 0
    private(set) var presentCallCount = 0
    var outcome: Outcome

    init(isReady: Bool = true, outcome: Outcome = .success) {
        self.outcome = outcome
        super.init()
        self.isReady = isReady
    }

    override func preload() {
        preloadCallCount += 1
        if outcome != .notReady {
            isReady = true
        }
    }

    @MainActor
    override func present() async throws {
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
