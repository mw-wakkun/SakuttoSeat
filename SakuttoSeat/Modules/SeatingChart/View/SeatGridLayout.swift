//
//  SeatGridLayout.swift
//  SakuttoSeat
//

import SwiftUI

/// 座席を指定列数で並べる即時レイアウトのグリッド。
///
/// 単一の `ForEach` で並べた座席を、そのまま行・列に配置するためのカスタム Layout。
/// 既存の選択肢では次の理由で要件を満たせないため自前で用意している。
///
/// - `LazyVGrid`: 画面外を描画せず親の高さを過小評価するため、テーブルが見切れる
/// - `Grid` / `GridRow`: 行ごとに `ForEach` を入れ子にする必要があり、座席の identity が
///   行と列の位置に埋もれる。その結果シャッフル時に SwiftUI が座席の「移動」を検出できず、
///   削除と挿入として扱われてアニメーションが失われる
///
/// この Layout では全座席が単一階層の兄弟として並ぶため、
/// 並び替えが「移動」として認識され、滑らかにアニメーションする。
struct SeatGridLayout: Layout {
    /// 1行に並べる座席数
    var columnCount: Int
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 12
    /// 1座席の最小幅。横スクロールさせる多列レイアウトで座席が潰れるのを防ぐ。
    /// 4列以下の通常レイアウトでは 0 のままにして、カード幅に合わせて均等割りさせる。
    var minCellWidth: CGFloat = 0

    private var columns: Int { max(1, columnCount) }

    /// 1座席あたりの幅
    private func cellWidth(proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        let totalSpacing = horizontalSpacing * CGFloat(columns - 1)

        if let proposedWidth = proposal.width, proposedWidth > 0 {
            return max(minCellWidth, (proposedWidth - totalSpacing) / CGFloat(columns))
        }

        // 幅の提案がない場合は、最も広い座席の理想幅にそろえる
        let idealWidth = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .max() ?? 0
        return max(minCellWidth, idealWidth)
    }

    /// 行ごとの高さ（その行で最も高い座席に合わせる）
    private func rowHeights(cellWidth: CGFloat, subviews: Subviews) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            let end = min(start + columns, subviews.count)
            return (start..<end)
                .map { subviews[$0].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }
                .max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let width = cellWidth(proposal: proposal, subviews: subviews)
        let heights = rowHeights(cellWidth: width, subviews: subviews)

        // 最終行が埋まっていなくても列数ぶんの幅を返し、テーブルごとの横幅を揃える
        return CGSize(
            width: width * CGFloat(columns) + horizontalSpacing * CGFloat(columns - 1),
            height: heights.reduce(0, +) + verticalSpacing * CGFloat(max(0, heights.count - 1))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let width = cellWidth(proposal: proposal, subviews: subviews)
        let heights = rowHeights(cellWidth: width, subviews: subviews)

        var y = bounds.minY
        for (row, rowHeight) in heights.enumerated() {
            let start = row * columns
            let end = min(start + columns, subviews.count)
            var x = bounds.minX

            for index in start..<end {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: rowHeight)
                )
                x += width + horizontalSpacing
            }
            y += rowHeight + verticalSpacing
        }
    }
}
