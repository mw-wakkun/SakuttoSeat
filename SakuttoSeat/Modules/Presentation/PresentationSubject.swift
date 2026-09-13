//
//  PresentationSubject.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表キャンバスの入力。ShareSubject と同じく ViewData のスナップショット）
//

import Foundation

/// 発表に出す対象。ホスト Presenter がタップ時点の ViewData を渡す。
enum PresentationSubject: Equatable {
    case seatingChart(SeatingChartViewData)
    case numberedList(SimpleShuffleViewData)
}
