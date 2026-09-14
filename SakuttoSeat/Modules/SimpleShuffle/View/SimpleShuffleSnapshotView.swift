//
//  SimpleShuffleSnapshotView.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 2（共有画像用。入力は ViewData。番号は再計算しない）
//  refactor_simple.md Phase 3（Copy / 既定 tint。行クロムはこの View 内に閉じる）
//  v2.1 Phase 2（高画質はタイト余白・広めの行間。画面用 View には広げない）
//  v2.1 hotfix（高画質は人数に応じて複数列。1 列の巨大画像で出力失敗しない）
//

import SwiftUI

struct SimpleShuffleSnapshotView: View {
    /// 標準 / 高画質のレイアウト差。画面の `SimpleShuffleView` には使わない。
    nonisolated enum Layout: Equatable, Sendable {
        case standard
        case highRes

        var exportWidth: CGFloat {
            exportWidth(rowCount: 1)
        }

        /// 高画質は人数が増えると複数列にする。幅も列数に合わせて広げる。
        func exportWidth(rowCount: Int) -> CGFloat {
            switch self {
            case .standard:
                return SimpleShuffleSnapshotView.exportWidth
            case .highRes:
                return columnCount(rowCount: rowCount) == 1
                    ? SimpleShuffleSnapshotView.highResExportWidth
                    : SimpleShuffleSnapshotView.highResMultiColumnExportWidth
            }
        }

        /// 1 列のままだと人数上限で画像が高さ上限を超え、ImageRenderer が失敗する。
        func columnCount(rowCount: Int) -> Int {
            switch self {
            case .standard:
                return 1
            case .highRes:
                let perColumn = SimpleShuffleSnapshotView.highResRowsPerColumn
                return max(1, (rowCount + perColumn - 1) / perColumn)
            }
        }

        var contentPadding: CGFloat {
            switch self {
            case .standard:
                return 20
            case .highRes:
                return 8
            }
        }

        var sectionSpacing: CGFloat {
            switch self {
            case .standard:
                return 16
            case .highRes:
                return 20
            }
        }

        var rowSpacing: CGFloat {
            switch self {
            case .standard:
                return 8
            case .highRes:
                return 12
            }
        }

        var rowPadding: CGFloat {
            switch self {
            case .standard:
                return 12
            case .highRes:
                return 16
            }
        }
    }

    /// 出力幅。`ImageExportRenderer` と共有する唯一の定義
    nonisolated static let exportWidth: CGFloat = 400
    /// 高画質は内容幅にフィット（目安 600〜834）
    nonisolated static let highResExportWidth: CGFloat = 680
    /// 複数列時は目安の上限まで広げ、氏名が潰れないようにする
    nonisolated static let highResMultiColumnExportWidth: CGFloat = 834
    /// 3x でも GPU 長辺上限に収まる 1 列あたりの行数
    nonisolated static let highResRowsPerColumn = 30

    let viewData: SimpleShuffleViewData
    var layout: Layout = .standard

    var body: some View {
        let columnCount = layout.columnCount(rowCount: viewData.rows.count)
        VStack(spacing: layout.sectionSpacing) {
            VStack(spacing: 4) {
                Text(SimpleShuffleCopy.snapshotBrand)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                Text(SimpleShuffleCopy.snapshotTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            if columnCount == 1 {
                rowsStack(viewData.rows, showsAccessory: true)
            } else {
                HStack(alignment: .top, spacing: layout.rowSpacing) {
                    ForEach(0..<columnCount, id: \.self) { column in
                        rowsStack(rows(inColumn: column, columnCount: columnCount), showsAccessory: false)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .padding(layout.contentPadding)
    }

    private func rows(inColumn column: Int, columnCount: Int) -> [SimpleShuffleViewData.Row] {
        let total = viewData.rows.count
        let rowsPerColumn = (total + columnCount - 1) / columnCount
        let start = column * rowsPerColumn
        guard start < total else { return [] }
        return Array(viewData.rows[start..<min(start + rowsPerColumn, total)])
    }

    private func rowsStack(_ rows: [SimpleShuffleViewData.Row], showsAccessory: Bool) -> some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(rows) { row in
                snapshotRow(row, showsAccessory: showsAccessory)
            }
        }
    }

    /// 共有画像専用の行クロム。画面 List や他モジュールには広げない。
    private func snapshotRow(_ row: SimpleShuffleViewData.Row, showsAccessory: Bool) -> some View {
        NumberedPersonRow(
            number: row.number,
            name: row.name,
            accessory: showsAccessory ? SimpleShuffleCopy.accessory : nil,
            rowVerticalPadding: layout == .highRes ? 2 : 0
        )
        .padding(layout.rowPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
