//
//  PresentationCopy.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表モードの文言を 1 系統にまとめる）
//  v2.1 UI/UX（ツールバー「発表」、無効 Hint、閉じるボタンの約束）
//

import Foundation

enum PresentationCopy {
    static var presentToolbarTitle: String { String(localized: "発表") }
    static var presentAccessibilityLabel: String { String(localized: "発表") }
    static var presentAccessibilityHint: String { String(localized: "座席表を全画面で表示します") }
    static var numberedPresentAccessibilityHint: String { String(localized: "番号札を全画面で表示します") }
    static var seatingPresentDisabledHint: String { String(localized: "テーブルがないと発表できません") }
    static var numberedPresentDisabledHint: String { String(localized: "参加者がいないと発表できません") }
    static var dismissTitle: String { String(localized: "閉じる") }
    static var dismissAccessibilityLabel: String { String(localized: "発表を終了") }
    static var tapToDismissHint: String { String(localized: "画面をタップすると閉じるボタンが出ます") }
}
