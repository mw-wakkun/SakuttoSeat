//
//  FavoriteGroupView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER）
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
                            message: "登録されているグループはありません"
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .listRowInsets(EdgeInsets())
                    }
                } else {
                    Section {
                        ForEach(presenter.viewData.groups) { group in
                            Button {
                                presenter.didSelectGroup(id: group.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(group.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(group.memberSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
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
                "削除に失敗しました",
                isPresented: alertIsPresentedBinding,
                presenting: presenter.alert,
                actions: { _ in
                    Button("OK", role: .cancel) { presenter.dismissAlert() }
                },
                message: { alert in
                    if case .deleteFailed(let message) = alert {
                        Text(message)
                    }
                }
            )
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            presenter.onAppear()
        }
    }

    private var alertIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { presenter.alert != nil },
            set: { isPresented in
                if !isPresented {
                    presenter.dismissAlert()
                }
            }
        )
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
