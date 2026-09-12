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

/// 広告提示中に画面が閉じられたときの破棄を検証するためのハング Fake。
final class RewardedAdGatewayHangingFake: RewardedAdGatewayBase {
    private let lock = NSLock()
    private var presentContinuation: CheckedContinuation<Void, Error>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var didStartPresenting = false

    @MainActor
    func waitUntilPresentStarted() async {
        if didStartPresenting { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    @MainActor
    func finishSuccessfully() {
        resumePresent(success: true)
    }

    @MainActor
    override func present() async throws {
        didStartPresenting = true
        startedContinuation?.resume()
        startedContinuation = nil
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.lock.lock()
                self.presentContinuation = continuation
                self.lock.unlock()
            }
        } onCancel: {
            self.resumePresent(success: false)
        }
    }

    private func resumePresent(success: Bool) {
        lock.lock()
        let continuation = presentContinuation
        presentContinuation = nil
        lock.unlock()
        if success {
            continuation?.resume(returning: ())
        } else {
            continuation?.resume(throwing: CancellationError())
        }
    }
}
