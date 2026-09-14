//
//  PresentationDismissGesture.swift
//  SakuttoSeat
//
//  v2.1 UI/UX（発表の下スワイプ閉じ。縦スクロールが内容を動かしているときは閉じない）
//

import CoreGraphics

enum PresentationDismissGesture {
    static let heightThreshold: CGFloat = 80
    /// 画面上端からの閉じスワイプ。キャンバス中央のパンと混ぜない。
    static let topEdgeLimit: CGFloat = 100
    /// 先頭判定の余裕。バウンスや inset の誤差で誤って閉じないようにする。
    static let topSlop: CGFloat = 1

    /// 内容が先頭にあり、画面上端から下方向が主で閾値を超えたときだけ閉じる。
    static func shouldDismiss(
        translation: CGSize,
        startLocation: CGPoint,
        isScrollAtTop: Bool
    ) -> Bool {
        guard isScrollAtTop, startLocation.y < topEdgeLimit else { return false }
        let height = translation.height
        return height > heightThreshold && abs(translation.width) < height / 2
    }

    static func isScrollAtTop(offsetY: CGFloat, insetTop: CGFloat) -> Bool {
        offsetY <= insetTop + topSlop
    }
}
