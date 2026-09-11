//
//  SavedListRow.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 5（お気に入り一覧とテンプレート一覧で共有する名前 + キャプション行）
//

import SwiftUI

struct SavedListRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
