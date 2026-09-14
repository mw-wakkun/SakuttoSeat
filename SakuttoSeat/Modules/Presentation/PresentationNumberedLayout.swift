//
//  PresentationNumberedLayout.swift
//  SakuttoSeat
//
//  v2.1 UI/UX（番号札発表の列数。書き出し Snapshot には繋げない）
//

import CoreGraphics

/// 発表キャンバスの番号札グリッド。1人は1列。幅が足りれば 2–4 列。
enum PresentationNumberedLayout {
    static func columnCount(rowCount: Int, containerWidth: CGFloat) -> Int {
        guard rowCount > 1 else { return 1 }
        let maxColumns: Int
        if containerWidth < 500 {
            maxColumns = 2
        } else if containerWidth < 700 {
            maxColumns = 3
        } else {
            maxColumns = 4
        }
        return min(maxColumns, rowCount)
    }
}
