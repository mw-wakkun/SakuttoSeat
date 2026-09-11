//
//  RewardedAdError.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 1（Presentation から移設。SDK 型は持たない）
//

import Foundation

enum RewardedAdError: Error, Equatable {
    /// 広告が未ロード、または提示先 VC が取れない
    case notReady
    /// 視聴は完了したが報酬未獲得のまま閉じた
    case notEarned
    /// 提示自体に失敗した
    case failed(String)
}
