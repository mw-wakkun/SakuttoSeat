//
//  SimpleShuffleSnapshotView.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 2（共有画像用。入力は ViewData。番号は再計算しない）
//  refactor_simple.md Phase 3（Copy / 既定 tint。行クロムはこの View 内に閉じる）
//

import SwiftUI

struct SimpleShuffleSnapshotView: View {
    /// 出力幅。`ImageExportRenderer` と共有する唯一の定義
    static let exportWidth: CGFloat = 400

    let viewData: SimpleShuffleViewData

    var body: some View {
        VStack(spacing: 16) {
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

            VStack(spacing: 8) {
                ForEach(viewData.rows) { row in
                    snapshotRow(row)
                }
            }
        }
        .padding(20)
    }

    /// 共有画像専用の行クロム。画面 List や他モジュールには広げない。
    private func snapshotRow(_ row: SimpleShuffleViewData.Row) -> some View {
        NumberedPersonRow(
            number: row.number,
            name: row.name,
            accessory: SimpleShuffleCopy.accessory,
            rowVerticalPadding: 0
        )
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
