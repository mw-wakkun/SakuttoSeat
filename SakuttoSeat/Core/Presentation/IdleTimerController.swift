//
//  IdleTimerController.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表中の自動ロック防止。ShareSheetPresenter と同じ格の Router ヘルパ）
//

import UIKit

/// 投影中に画面が消灯しないよう、アイドルタイマを切り替える。
/// 機能 View / Presenter は UIApplication を見ず、Router 経由でここを呼ぶ。
enum IdleTimerController {
    @MainActor
    static func setDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
