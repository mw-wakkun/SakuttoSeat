//
//  PresentationCopy.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表モードの文言を 1 系統にまとめる）
//

import Foundation

enum PresentationCopy {
    static var presentAccessibilityLabel: String { String(localized: "発表") }
    static var presentAccessibilityHint: String { String(localized: "座席表を全画面で表示します") }
    static var numberedPresentAccessibilityHint: String { String(localized: "番号札を全画面で表示します") }
    static var dismissTitle: String { String(localized: "閉じる") }
    static var dismissAccessibilityLabel: String { String(localized: "発表を終了") }
    static var tapToDismissHint: String { String(localized: "画面をタップして終了") }
}
