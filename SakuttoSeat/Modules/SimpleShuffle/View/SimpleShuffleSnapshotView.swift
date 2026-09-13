//
//  SimpleShuffleSnapshotView.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 2（共有画像用。入力は ViewData。番号は再計算しない）
//  refactor_simple.md Phase 3（Copy / 既定 tint。行クロムはこの View 内に閉じる）
//  v2.1 Phase 2（高画質はタイト余白・広めの行間。画面用 View には広げない）
//

import SwiftUI

struct SimpleShuffleSnapshotView: View {
    /// 標準 / 高画質のレイアウト差。画面の `SimpleShuffleView` には使わない。
    nonisolated enum Layout: Equatable, Sendable {
        case standard
        case highRes

        var exportWidth: CGFloat {
            switch self {
            case .standard:
                return SimpleShuffleSnapshotView.exportWidth
            case .highRes:
                return SimpleShuffleSnapshotView.highResExportWidth
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
    static let exportWidth: CGFloat = 400
    /// 高画質は内容幅にフィット（目安 600〜834）
    static let highResExportWidth: CGFloat = 680

    let viewData: SimpleShuffleViewData
    var layout: Layout = .standard

    var body: some View {
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

            VStack(spacing: layout.rowSpacing) {
                ForEach(viewData.rows) { row in
                    snapshotRow(row)
                }
            }
        }
        .padding(layout.contentPadding)
    }

    /// 共有画像専用の行クロム。画面 List や他モジュールには広げない。
    private func snapshotRow(_ row: SimpleShuffleViewData.Row) -> some View {
        NumberedPersonRow(
            number: row.number,
            name: row.name,
            accessory: SimpleShuffleCopy.accessory,
            rowVerticalPadding: layout == .highRes ? 2 : 0
        )
        .padding(layout.rowPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
