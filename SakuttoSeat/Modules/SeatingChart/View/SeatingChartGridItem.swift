//
//  SeatingChartGridItem.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）
//

import Foundation

/// 座席表グリッドの1セル（テーブル or 追加ボタン）
///
/// Phase 2 で `SeatingChartViewData` の一部として Presenter 側へ移送する予定。
enum SeatingChartGridItem: Identifiable {
    case table(Int)
    case addButton

    var id: String {
        switch self {
        case .table(let index):
            return "table-\(index)"
        case .addButton:
            return "add-button"
        }
    }
}
