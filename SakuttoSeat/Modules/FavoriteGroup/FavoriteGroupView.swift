//
//  FavoriteGroupView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER）
//  refactor_favorite.md Phase 1（文言は FavoriteGroupCopy。Gateway は assemble 時注入）
//  refactor_favorite.md Phase 2（View は ViewData.Row と route のみ）
//  refactor_favorite.md Phase 4（presentationDetents は Router 組み立て側）
//  一覧・削除は Presenter → Interactor。選択結果は Output のみ。
//  Gateway は親が assemble 時に同じインスタンスを渡す（子 View は ModelContext を持たない）。
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
                            message: FavoriteGroupCopy.emptyMessage
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
                            .accessibilityHint(FavoriteGroupCopy.selectAccessibilityHint)
                        }
                        .onDelete { offsets in
                            presenter.didDeleteGroups(at: offsets)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(FavoriteGroupCopy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(FavoriteGroupCopy.close) { presenter.didTapClose() }
                }
            }
            .alert(
                alertTitle,
                isPresented: alertIsPresentedBinding,
                presenting: presentedAlert,
                actions: { _ in
                    Button(FavoriteGroupCopy.ok, role: .cancel) { presenter.dismissRoute() }
                },
                message: { alert in
                    alertMessage(for: alert)
                }
            )
        }
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
            return FavoriteGroupCopy.deleteFailedTitle
        case .loadFailed:
            return FavoriteGroupCopy.loadFailedTitle
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
@MainActor
private enum FavoriteGroupPreviewFactory {
    static func makePresenter(populated: Bool) -> FavoriteGroupPresenter {
        let gateway = InMemoryGroupFavoriteGateway()
        if populated {
            try? gateway.insert(name: "同期", members: ["太郎", "花子"])
        }
        return FavoriteGroupPresenter(
            interactor: FavoriteGroupInteractor(favoriteGateway: gateway),
            output: nil
        )
    }
}

#Preview("お気に入りグループ") {
    FavoriteGroupView(presenter: FavoriteGroupPreviewFactory.makePresenter(populated: true))
}

#Preview("お気に入りグループ（空）") {
    FavoriteGroupView(presenter: FavoriteGroupPreviewFactory.makePresenter(populated: false))
}
#endif
