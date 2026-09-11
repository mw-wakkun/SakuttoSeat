//
//  FavoriteGroupView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER）
//  refactor_favorite.md Phase 1（文言は FavoriteGroupCopy。Gateway は assemble 時注入）
//  refactor_favorite.md Phase 2（View は ViewData.Row と route のみ）
//  refactor_favorite.md Phase 4（presentationDetents は Router 組み立て側）
//  refactor_favorite.md Phase 5（SavedListRow / SheetChromeToolbar。編集中は選択しない）
//  一覧・削除は Presenter → Interactor。選択結果は Output のみ。
//  Gateway は親が assemble 時に同じインスタンスを渡す（子 View は ModelContext を持たない）。
//

import SwiftUI

struct FavoriteGroupView: View {
    @StateObject var presenter: FavoriteGroupPresenter
    @State private var editMode: EditMode = .inactive

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
                                // 編集モード中は誤操作を防ぐため読み込みを無効化（テンプレ一覧と同じ）
                                guard editMode == .inactive else { return }
                                presenter.didSelectGroup(id: row.id)
                            } label: {
                                SavedListRow(title: row.name, subtitle: row.memberSummary)
                            }
                            .accessibilityLabel(row.name)
                            .accessibilityValue(row.memberSummary)
                            .accessibilityHint(FavoriteGroupCopy.selectAccessibilityHint)
                        }
                        .onDelete { offsets in
                            presenter.didDeleteGroups(at: offsets)
                            if presenter.viewData.isEmpty {
                                editMode = .inactive
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .navigationTitle(FavoriteGroupCopy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetChromeToolbar(
                    isEditing: editMode == .active,
                    showsEditButton: !presenter.viewData.isEmpty,
                    editTitle: FavoriteGroupCopy.edit,
                    closeTitle: FavoriteGroupCopy.close,
                    onToggleEdit: {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    },
                    onClose: { presenter.didTapClose() }
                )
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
