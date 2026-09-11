//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_simple.md Phase 3（既定 tint / Copy 一系統 / canShuffle / A11y）
//

import SwiftUI

struct SimpleShuffleView: View {
    // Presenter の所有権は 3 モジュールで @StateObject に統一している
    // （@ObservedObject では親の再評価ごとに Presenter が作り直され、シャッフル結果が失われる）
    @StateObject var presenter: SimpleShufflePresenter

    var body: some View {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerContainer()
                .padding(.vertical, AppSpacing.bannerVerticalPadding)
                .frame(maxWidth: .infinity)
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
