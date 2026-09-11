//
//  RewardedAdPresentationState.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 3（報酬フラグと dismiss の順序を SDK なしで固定する）
//

import Foundation

/// リワード提示 1 回分の報酬フラグと完了状態。
///
/// Google の userDidEarnReward は `adDidDismissFullScreenContent` より先に来るが、
/// フラグ立てを `Task { @MainActor }` に遅延すると dismiss に負ける。
/// **earned は SDK コールバック内で同期的に `markEarned()` すること。**
///
/// `nonisolated`: デフォルト MainActor 隔離だと、Impl の lock 内およびテストから Equatable を呼べない。
nonisolated struct RewardedAdPresentationState: Equatable {
    enum Completion: Equatable {
        case earned
        case notEarned
        case failed(String)
        case alreadyFinished
    }

    private(set) var isPresenting = false
    private(set) var hasEarnedReward = false
    private(set) var didFinish = false

    /// 提示開始。すでに提示中なら false。
    mutating func beginPresenting() -> Bool {
        guard !isPresenting else { return false }
        isPresenting = true
        hasEarnedReward = false
        didFinish = false
        return true
    }

    /// userDidEarnReward 内で同期的に呼ぶ。Task を挟まない。
    mutating func markEarned() {
        guard isPresenting, !didFinish else { return }
        hasEarnedReward = true
    }

    mutating func dismiss() -> Completion {
        complete(hasEarnedReward ? .earned : .notEarned)
    }

    mutating func fail(_ message: String) -> Completion {
        complete(.failed(message))
    }

    /// 未 dismiss のまま破棄されたとき。
    mutating func abortIfPresenting() -> Completion {
        complete(.failed("広告の提示が中断されました"))
    }

    private mutating func complete(_ completion: Completion) -> Completion {
        guard isPresenting, !didFinish else { return .alreadyFinished }
        didFinish = true
        isPresenting = false
        hasEarnedReward = false
        return completion
    }
}
