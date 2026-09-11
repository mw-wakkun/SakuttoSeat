//
//  ImageExportRenderer.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（ImageRenderer ラッパ）
//  Phase 5（出力サイズの実測化・`UIScreen.main` 依存の排除）
//  refactor_simple.md Phase 2（番号札は Snapshot の exportWidth と ViewData を使う）
//

import SwiftUI
import UIKit

@MainActor
enum ImageExportRenderer {
    /// 幅はスナップショット View のレイアウト定数から確定させ、
    /// 高さは提案しない（`ImageRenderer` に実測させる）。
    /// これで定員が多いテーブルでも下端が見切れない。
    static func renderSeatingChart(viewData: SeatingChartViewData) -> UIImage? {
        let exportWidth = SeatingChartSnapshotView.intrinsicWidth(columnCount: viewData.globalColumnCount)

        let exportView = SeatingChartSnapshotView(viewData: viewData)
            .frame(width: exportWidth, alignment: .topLeading)
            .background(Color(.systemBackground))

        return render(exportView, width: exportWidth)
    }

    static func renderSimpleShuffle(viewData: SimpleShuffleViewData) -> UIImage? {
        let exportWidth = SimpleShuffleSnapshotView.exportWidth
        let exportView = SimpleShuffleSnapshotView(viewData: viewData)
            .frame(width: exportWidth)
            .background(Color(.systemGroupedBackground))

        return render(exportView, width: exportWidth)
    }

    private static func render<Content: View>(_ content: Content, width: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    /// キーウィンドウの表示スケール（`UIScreen.main` は iOS 16 以降非推奨のため使わない）
    private static var displayScale: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) else {
            return 3
        }
        return window.traitCollection.displayScale
    }
}
