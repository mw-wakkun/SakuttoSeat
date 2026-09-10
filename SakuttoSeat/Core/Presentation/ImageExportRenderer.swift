//
//  ImageExportRenderer.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（ImageRenderer ラッパ）
//

import SwiftUI
import UIKit

@MainActor
enum ImageExportRenderer {
    static func renderSeatingChart(viewData: SeatingChartViewData) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let tableWidth: CGFloat = 140
        let tableSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 32

        let tableCount = CGFloat(viewData.globalColumnCount)
        let calculatedWidth = tableCount * tableWidth + (tableCount - 1) * tableSpacing + horizontalPadding
        let exportWidth = max(screenWidth, calculatedWidth)

        let tableHeight: CGFloat = 150
        let verticalSpacing: CGFloat = 16
        let verticalPadding: CGFloat = 32
        let tableOnlyCount = viewData.rows.reduce(0) { partial, row in
            partial + row.items.filter {
                if case .table = $0 { return true }
                return false
            }.count
        }
        let tableRowCount = ceil(CGFloat(tableOnlyCount) / CGFloat(max(1, viewData.globalColumnCount)))
        let calculatedHeight = tableRowCount * (tableHeight + verticalSpacing) + verticalPadding
        let exportHeight = max(400, calculatedHeight)

        let exportView = SeatingChartSnapshotView(viewData: viewData)
            .frame(width: exportWidth, height: exportHeight, alignment: .topLeading)
            .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: exportHeight)
        return renderer.uiImage
    }

    static func renderSimpleShuffle(attendees: [String]) -> UIImage? {
        let exportWidth: CGFloat = 400
        let exportView = SimpleShuffleSnapshotView(attendees: attendees)
            .frame(width: exportWidth)
            .background(Color(.systemGroupedBackground))

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: nil)
        return renderer.uiImage
    }
}
