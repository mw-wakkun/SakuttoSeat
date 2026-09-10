//
//  FeatureUnlockGatewayImpl.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 3（セッション解放状態の所在）
//
//  Protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
//  Interactor は具象クラスだけを保持する。
//

import Foundation

nonisolated final class FeatureUnlockState: FeatureUnlockGateway {
    private(set) var isSessionUnlocked: Bool

    init(isSessionUnlocked: Bool = false) {
        self.isSessionUnlocked = isSessionUnlocked
    }

    func grantSessionUnlock() {
        isSessionUnlocked = true
    }
}

/// アプリ起動中だけ有効な列数解放状態。画面を pop しても同一セッションなら維持する。
enum SessionFeatureUnlock {
    static let shared = FeatureUnlockState()
}
