//
//  ShareSelectionView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/23.
//  refactor_seating.md Phase 5 で Modules/Common から Share モジュールへ移動。
//  v2.1 Phase 1（4択。未解放の有料は動画アイコン、解放済みは南京錠なし）
//  v2.1 UI/UX（medium+large、スクロール、対象別字幕、chevron なし）
//

import SwiftUI

/// 共有方法の選択シート
///
/// 選択後のシート閉じは Presenter（`route = nil`）が行うため、ここでは通知だけを行う。
struct ShareSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let isExportUnlocked: Bool
    /// 字幕の対象。nil のときは座席表側へフォールバックする。
    let subject: ShareSubject?
    let onSelect: (ShareSelectionKind) -> Void

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ShareSelectionKind.allCases, id: \.self) { kind in
                        shareOptionButton(
                            icon: ShareCopy.iconName(for: kind),
                            title: ShareCopy.title(for: kind),
                            subtitle: ShareCopy.subtitle(
                                for: kind,
                                isExportUnlocked: isExportUnlocked,
                                subject: subject
                            ),
                            tint: tint(for: kind),
                            showsRewardBadge: needsRewardBadge(for: kind)
                        ) {
                            onSelect(kind)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("キャンセル") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }

    private func needsRewardBadge(for kind: ShareSelectionKind) -> Bool {
        switch kind {
        case .text:
            return false
        case .image, .highResImage, .csv:
            return !isExportUnlocked
        }
    }

    private func tint(for kind: ShareSelectionKind) -> Color {
        switch kind {
        case .text:
            return .sakuttoBlueStart
        case .image:
            return .purple
        case .highResImage:
            return .indigo
        case .csv:
            return .teal
        }
    }

    private func shareOptionButton(
        icon: String,
        title: String,
        subtitle: String?,
        tint: Color,
        showsRewardBadge: Bool,
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
                            .multilineTextAlignment(.leading)
                            .lineLimit(1...2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsRewardBadge {
                    Image(systemName: "play.rectangle.fill")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(ShareCopy.rewardBadgeAccessibilityLabel)
                }
            }
            .padding(Self.optionPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(ShareOptionButtonStyle())
    }

    /// 行の内側余白（旧 14pt。SE の medium detent に収める）
    private static let optionPadding: CGFloat = 12
}

/// `.plain` 相当。プッシュ遷移ではないので chevron は出さず、押下時だけ薄くする。
private struct ShareOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#if DEBUG
#Preview("共有シート・座席表・未解放") {
    ShareSelectionView(
        isExportUnlocked: false,
        subject: .seatingChart(.empty),
        onSelect: { _ in }
    )
}

#Preview("共有シート・番号札・未解放") {
    ShareSelectionView(
        isExportUnlocked: false,
        subject: .numberedList(.empty),
        onSelect: { _ in }
    )
}

#Preview("共有シート・解放済み") {
    ShareSelectionView(
        isExportUnlocked: true,
        subject: .seatingChart(.empty),
        onSelect: { _ in }
    )
}
#endif
