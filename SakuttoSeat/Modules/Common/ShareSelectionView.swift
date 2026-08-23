//
//  ShareSelectionView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/23.
//

import SwiftUI

enum ShareSelectionKind {
    case text
    case image
}

struct ShareSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premiumManager = PremiumManager.shared
    let onSelect: (ShareSelectionKind) -> Void
    
    var body: some View {
        VStack(spacing: 24) { // タイトルがない分、少し余白を広げてバランスをとる
            VStack(spacing: 12) {
                shareOptionButton(
                    icon: "doc.text",
                    title: "テキストで共有",
                    subtitle: nil,
                    tint: .sakuttoBlueStart
                ) {
                    select(.text)
                }
                
                shareOptionButton(
                    icon: "photo",
                    title: "画像で共有",
                    subtitle: premiumManager.isPro ? nil : "短い動画広告の視聴が必要です",
                    tint: .purple
                ) {
                    select(.image)
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
    
    private func select(_ kind: ShareSelectionKind) {
        onSelect(kind)
        dismiss()
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
