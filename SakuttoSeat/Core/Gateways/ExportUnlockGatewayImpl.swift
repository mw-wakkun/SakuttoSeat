//
//  ExportUnlockGatewayImpl.swift
//  SakuttoSeat
//
//  v2.1 Phase 1（書き出し用セッション解放状態の所在）
//
//  列数の `FeatureUnlockState` と同じ形だが、別インスタンス。
//  3列の動画で CSV は開かない。CSV の動画で3列も開かない。
//  Protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
//  Interactor は具象クラスだけを保持する。
//

import Foundation

nonisolated final class ExportUnlockState: ExportUnlockGateway {
    private(set) var isSessionUnlocked: Bool

    init(isSessionUnlocked: Bool = false) {
        self.isSessionUnlocked = isSessionUnlocked
    }

    func grantSessionUnlock() {
        isSessionUnlocked = true
    }
}

/// アプリ起動中だけ有効な書き出し解放状態。画面を pop しても同一セッションなら維持する。
enum SessionExportUnlock {
    static let shared = ExportUnlockState()
}
