//
//  ImageExportRenderer.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（ImageRenderer ラッパ）
//  Phase 5（出力サイズの実測化・`UIScreen.main` 依存の排除）
//  refactor_simple.md Phase 2（番号札は Snapshot の exportWidth と ViewData を使う）
//  v2.1 Phase 2（高画質は scale 3.0 以上・タイト余白。PNG は一時ファイル）
//

import SwiftUI
import UIKit

@MainActor
enum ImageExportRenderer {
    /// 高画質の最低スケール。端末がそれ以上なら displayScale を使う。
    static let highResScale: CGFloat = 3

    /// 幅はスナップショット View のレイアウト定数から確定させ、
    /// 高さは提案しない（`ImageRenderer` に実測させる）。
    /// これで定員が多いテーブルでも下端が見切れない。
    static func renderSeatingChart(
        viewData: SeatingChartViewData,
        quality: ExportQuality = .standard
    ) -> UIImage? {
        let layout = seatingLayout(for: quality)
        let columnCount = SeatingChartSnapshotView.exportColumnCount(for: viewData, layout: layout)
        let exportWidth = SeatingChartSnapshotView.intrinsicWidth(columnCount: columnCount, layout: layout)

        let exportView = SeatingChartSnapshotView(viewData: viewData, layout: layout)
            .frame(width: exportWidth, alignment: .topLeading)
            .background(Color(.systemBackground))

        return render(exportView, width: exportWidth, quality: quality)
    }

    static func renderSimpleShuffle(
        viewData: SimpleShuffleViewData,
        quality: ExportQuality = .standard
    ) -> UIImage? {
        let layout = shuffleLayout(for: quality)
        let exportWidth = layout.exportWidth
        let exportView = SimpleShuffleSnapshotView(viewData: viewData, layout: layout)
            .frame(width: exportWidth)
            .background(Color(.systemGroupedBackground))

        return render(exportView, width: exportWidth, quality: quality)
    }

    /// 高画質 PNG を一時ディレクトリへ書く。失敗したら nil。呼び出し側が共有後に捨てる。
    static func writeTemporaryPNG(_ image: UIImage, fileName: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 標準は端末の displayScale。高画質は常に 3.0 以上。
    static func renderScale(for quality: ExportQuality, displayScale: CGFloat? = nil) -> CGFloat {
        let deviceScale = displayScale ?? Self.displayScale
        switch quality {
        case .standard:
            return deviceScale
        case .highRes:
            return max(highResScale, deviceScale)
        }
    }

    private static func render<Content: View>(
        _ content: Content,
        width: CGFloat,
        quality: ExportQuality
    ) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = renderScale(for: quality)
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    private static func seatingLayout(for quality: ExportQuality) -> SeatingChartSnapshotView.Layout {
        switch quality {
        case .standard:
            return .standard
        case .highRes:
            return .highRes
        }
    }

    private static func shuffleLayout(for quality: ExportQuality) -> SimpleShuffleSnapshotView.Layout {
        switch quality {
        case .standard:
            return .standard
        case .highRes:
            return .highRes
        }
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
