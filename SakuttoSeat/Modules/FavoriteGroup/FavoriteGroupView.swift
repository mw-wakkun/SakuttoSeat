//
//  FavoriteGroupView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER）
//  refactor_favorite.md Phase 2（View は ViewData.Row と route のみ）
//  一覧・削除は Presenter → Interactor。選択結果は Output のみ。
//  Gateway は親 assemble 時に渡す（同じ SwiftData context / In-Memory を共有）。
//

import SwiftUI

struct FavoriteGroupView: View {
    @StateObject var presenter: FavoriteGroupPresenter

    var body: some View {
        NavigationStack {
            List {
                if presenter.viewData.isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: "star.slash",
                            message: String(localized: "登録されているグループはありません")
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .listRowInsets(EdgeInsets())
                    }
                } else {
                    Section {
                        ForEach(presenter.viewData.rows) { row in
                            Button {
                                presenter.didSelectGroup(id: row.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(row.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(row.memberSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .accessibilityLabel(row.name)
                            .accessibilityValue(row.memberSummary)
                            .accessibilityHint(String(localized: "このグループを参加者リストに読み込みます"))
                        }
                        .onDelete { offsets in
                            presenter.didDeleteGroups(at: offsets)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("お気に入りグループ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { presenter.didTapClose() }
                }
            }
            .alert(
                alertTitle,
                isPresented: alertIsPresentedBinding,
                presenting: presentedAlert,
                actions: { _ in
                    Button("OK", role: .cancel) { presenter.dismissRoute() }
                },
                message: { alert in
                    alertMessage(for: alert)
                }
            )
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            presenter.onAppear()
        }
    }
}

// MARK: - Route Bindings

private extension FavoriteGroupView {
    var presentedAlert: FavoriteGroupAlert? {
        if case .alert(let alert) = presenter.route { return alert }
        return nil
    }

    var alertTitle: String {
        switch presentedAlert {
        case .deleteFailed:
            return String(localized: "削除に失敗しました")
        case .loadFailed:
            return String(localized: "読み込みに失敗しました")
        case .none:
            return ""
        }
    }

    var alertIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { presentedAlert != nil },
            set: { isPresented in
                if !isPresented, case .alert = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    func alertMessage(for alert: FavoriteGroupAlert) -> Text {
        switch alert {
        case .deleteFailed(let message), .loadFailed(let message):
            Text(message)
        }
    }
}

#if DEBUG
#Preview("お気に入りグループ") {
    FavoriteGroupView(
        presenter: FavoriteGroupPresenter(
            interactor: FavoriteGroupInteractor(),
            output: nil
        )
    )
}
#endif
