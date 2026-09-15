//
//  SeatingChartCopy.swift
//  SakuttoSeat
//
//  v2.1 UI/UX（座席表の A11y 名・下段テンプレート・卓と席のアフォーダンス）
//

import Foundation

enum SeatingChartCopy {
    static var addTableTitle: String { String(localized: "テーブル追加") }
    static var addTableAccessibilityLabel: String { String(localized: "テーブルを追加") }
    static var addTableUnlockHint: String { String(localized: "動画を見るとテーブルを増やせます") }
    static var loadTemplateHint: String { String(localized: "保存済みレイアウトの一覧を開きます") }
    static var saveHint: String { String(localized: "現在のレイアウトをテンプレートとして保存します") }
    static var shareHint: String { String(localized: "座席表を共有します") }
    static var shuffleHint: String { String(localized: "席順をシャッフルします") }
    static var loadTemplateTitle: String { String(localized: "テンプレート") }
    static var editTableHint: String { String(localized: "ダブルタップでテーブルを編集します") }
    static var lockedValue: String { String(localized: "ロック中") }
    static var lockSeatHint: String { String(localized: "ダブルタップでロックします") }
    static var unlockSeatHint: String { String(localized: "ダブルタップでロックを解除します") }
}
