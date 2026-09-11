//
//  ShareSelectionView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/23.
//  refactor_seating.md Phase 5 で Modules/Common から Share モジュールへ移動。
//

import SwiftUI

/// 共有方法の選択シート
///
/// 選択後のシート閉じは Presenter（`route = nil`）が行うため、ここでは通知だけを行う。
struct ShareSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ShareSelectionKind) -> Void

    var body: some View {
        VStack(spacing: 24) { // タイトルがない分、少し余白を広げてバランスをとる
            VStack(spacing: 12) {
                shareOptionButton(
                    icon: "doc.text",
                    title: "テキストで共有",
                    subtitle: "無料ですぐに共有できます",
                    tint: .sakuttoBlueStart
                ) {
                    onSelect(.text)
                }

                shareOptionButton(
                    icon: "photo",
                    title: "画像で共有",
                    subtitle: "動画を見てきれいな座席表画像を保存・送信",
                    tint: .purple
                ) {
                    onSelect(.image)
                }
            }

            Button("キャンセル") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24) // 上部にも余白を持たせて上下中央に配置
        .padding(.bottom, 8)
        .presentationDetents([.fraction(0.3), .medium])
        .presentationDragIndicator(.visible)
    }

    private func shareOptionButton(
        icon: String,
        title: String,
        subtitle: String?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
