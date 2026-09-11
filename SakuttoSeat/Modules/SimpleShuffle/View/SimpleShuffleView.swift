//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_simple.md Phase 3（既定 tint / Copy 一系統 / canShuffle / A11y）
//  refactor_simple.md Phase 4（空状態 / insetGrouped。大量行の spring 抑制は未計測のため入れない）
//  番号札は inset がバナーのみなので、幅を containerRelativeFrame で確定する
//

import SwiftUI

struct SimpleShuffleView: View {
    // Presenter の所有権は 3 モジュールで @StateObject に統一している
    // （@ObservedObject では親の再評価ごとに Presenter が作り直され、シャッフル結果が失われる）
    @StateObject var presenter: SimpleShufflePresenter

    var body: some View {
        Group {
            if presenter.viewData.isEmpty {
                emptyContent
            } else {
                numberedList
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerContainer()
                .padding(.vertical, AppSpacing.bannerVerticalPadding)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(SimpleShuffleCopy.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    presenter.didTapShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                }
                .accessibilityLabel(SimpleShuffleCopy.shareAccessibilityLabel)
                .accessibilityHint(SimpleShuffleCopy.shareAccessibilityHint)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        presenter.didTapShuffle()
                    }
                    AccessibilityNotification.Announcement(SimpleShuffleCopy.shuffleAnnouncement).post()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.body).bold()
                }
                .disabled(!presenter.viewData.canShuffle)
                .accessibilityLabel(SimpleShuffleCopy.shuffleAccessibilityLabel)
                .accessibilityHint(
                    presenter.viewData.canShuffle
                        ? SimpleShuffleCopy.shuffleAccessibilityHint
                        : SimpleShuffleCopy.shuffleDisabledHint
                )
            }
        }
        .shareFlow(presenter.share)
    }
}

private extension SimpleShuffleView {
    var emptyContent: some View {
        EmptyStateView(
            systemImage: "person.3",
            message: SimpleShuffleCopy.emptyMessage,
            imageFont: .system(size: 80),
            imageColor: .sakuttoBlueStart.opacity(0.3),
            spacing: AppSpacing.emptyStateSpacing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    var numberedList: some View {
        List {
            Section {
                ForEach(presenter.viewData.rows) { row in
                    NumberedPersonRow(
                        number: row.number,
                        name: row.name,
                        accessory: SimpleShuffleCopy.accessory
                    )
                }
            } header: {
                Text(SimpleShuffleCopy.listHeader)
            } footer: {
                Text(SimpleShuffleCopy.listFooter)
            }
        }
        .listStyle(.insetGrouped)
    }
}
