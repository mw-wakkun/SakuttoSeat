//
//  ExportUnlockGateway.swift
//  SakuttoSeat
//
//  v2.1 Phase 1（書き出し用セッション解放。列数の FeatureUnlock とは別契約）
//

import Foundation

nonisolated protocol ExportUnlockGateway: AnyObject {
    var isSessionUnlocked: Bool { get }
    func grantSessionUnlock()
}
