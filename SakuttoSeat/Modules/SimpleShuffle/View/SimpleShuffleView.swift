//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_simple.md Phase 3（既定 tint / Copy 一系統 / canShuffle / A11y）
//  refactor_simple.md Phase 4（空状態 / insetGrouped。大量行の spring 抑制は未計測のため入れない）
//  番号札は inset がバナーのみ。幅は AdBannerContainer が containerRelativeFrame で確定する
//  refactor_Ad.md Phase 5（余白は Container 内。inset 背景だけ画面側）
//  v2.1 Phase 3（発表はナビ左。Cover 中はバナー inset を外す）
//  v2.1 UI/UX（発表ツールバーにラベル、無効時 Hint）
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
            if !isPresenting {
                AdBannerContainer()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .background {
            InteractivePopGestureController(isEnabled: !isPresenting)
        }
        .navigationTitle(SimpleShuffleCopy.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                PresentToolbarButton(
                    isEnabled: !presenter.viewData.isEmpty,
                    accessibilityHint: presenter.viewData.isEmpty
                        ? PresentationCopy.numberedPresentDisabledHint
                        : PresentationCopy.numberedPresentAccessibilityHint
                ) {
                    presenter.didTapPresent()
                }
            }
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
        .fullScreenCover(item: presentationRouteBinding) { route in
            presenter.makePresentationCover(route)
        }
    }
}

private extension SimpleShuffleView {
    var isPresenting: Bool {
        presenter.route?.presentsAsFullScreenCover == true
    }

    var presentationRouteBinding: Binding<SimpleShuffleRoute?> {
        Binding(
            get: {
                guard let route = presenter.route, route.presentsAsFullScreenCover else { return nil }
                return route
            },
            set: { newValue in
                if newValue == nil, presenter.route?.presentsAsFullScreenCover == true {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var emptyContent: some View {
        EmptyStateView(
            systemImage: "person.3",
            message: SimpleShuffleCopy.emptyMessage,
            imagePointSize: AppSpacing.emptyStateHeroIconSize,
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
