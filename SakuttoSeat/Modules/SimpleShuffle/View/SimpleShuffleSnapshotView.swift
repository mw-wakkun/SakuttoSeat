//
//  SimpleShuffleSnapshotView.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 2（共有画像用。入力は ViewData。番号は再計算しない）
//

import SwiftUI

struct SimpleShuffleSnapshotView: View {
    /// 出力幅。`ImageExportRenderer` と共有する唯一の定義
    static let exportWidth: CGFloat = 400

    let viewData: SimpleShuffleViewData

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("【サクッと席決め】")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                Text("シャッフル結果（番号札）")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(viewData.rows) { row in
                    NumberedPersonRow(
                        number: row.number,
                        name: row.name,
                        accessory: String(localized: "番席"),
                        tint: .blue,
                        rowVerticalPadding: 0
                    )
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
    }
}
