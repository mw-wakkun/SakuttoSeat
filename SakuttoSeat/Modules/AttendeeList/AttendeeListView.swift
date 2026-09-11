//
//  AttendeeListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 6（DesignSystem / safeAreaInset / A11y / キーボード）
//  refactor_Ad.md Phase 5（バナー余白は AdBannerContainer 内）
//  refactor_groupFavorite.md Phase 4（View は ModelContext / Gateway を知らない）
//

import SwiftUI

struct AttendeeListView: View {
    @StateObject var presenter: AttendeeListPresenter
    /// 未確定のキー入力。確定時だけ Presenter へ渡す
    @State private var newName = ""
    /// 保存アラートの TextField 用（route が `.saveFavoritePrompt` のときだけ使う）
    @State private var groupName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if presenter.viewData.isEmpty {
                    emptyContent
                } else {
                    VStack(spacing: 0) {
                        inputSection
                        attendeeList
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChromeBar
            }
            .background(Color(.systemBackground))
            .navigationTitle("サクッと席決め")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.sakuttoBlueStart, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("お気に入り登録", isPresented: savePromptBinding) {
                TextField("グループ名（例: 同期、〇〇課）", text: $groupName)
                Button("キャンセル", role: .cancel) { groupName = "" }
                Button("保存") {
                    presenter.didConfirmSaveFavorite(name: groupName)
                    groupName = ""
                }
            } message: {
                Text("現在のメンバーをグループとして保存します。")
            }
            .alert(
                alertTitle,
                isPresented: alertIsPresentedBinding,
                presenting: presentedAlert,
                actions: { alert in
                    alertButtons(for: alert)
                },
                message: { alert in
                    alertMessage(for: alert)
                }
            )
            .sheet(item: sheetRouteBinding) { route in
                presenter.makeRouteSheet(route)
            }
            .onAppear {
                presenter.onAppear()
                isTextFieldFocused = true
            }
            .navigationDestination(item: navigationRouteBinding) { route in
                presenter.makeRouteView(route)
            }
        }
    }
}

// MARK: - Route Bindings

private extension AttendeeListView {
    var sheetRouteBinding: Binding<AttendeeListRoute?> {
        Binding(
            get: {
                guard let route = presenter.route, route.presentsAsSheet else { return nil }
                return route
            },
            set: { newValue in
                if newValue == nil, let route = presenter.route, route.presentsAsSheet {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var navigationRouteBinding: Binding<AttendeeListRoute?> {
        Binding(
            get: {
                guard let route = presenter.route, route.presentsAsNavigation else { return nil }
                return route
            },
            set: { newValue in
                if newValue == nil, let route = presenter.route, route.presentsAsNavigation {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var savePromptBinding: Binding<Bool> {
        Binding(
            get: {
                if case .saveFavoritePrompt = presenter.route { return true }
                return false
            },
            set: { isPresented in
                if !isPresented, case .saveFavoritePrompt = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var presentedAlert: AttendeeListAlert? {
        if case .alert(let alert) = presenter.route { return alert }
        return nil
    }

    var alertTitle: String {
        switch presentedAlert {
        case .confirmReset:
            return String(localized: "参加者のリセット")
        case .favoriteLimitReached:
            return String(localized: "お気に入り上限")
        case .saveFailed:
            return String(localized: "保存に失敗しました")
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

    @ViewBuilder
    func alertButtons(for alert: AttendeeListAlert) -> some View {
        switch alert {
        case .confirmReset:
            Button("キャンセル", role: .cancel) { }
            Button("全員削除", role: .destructive) {
                presenter.didConfirmReset()
            }
        case .favoriteLimitReached, .saveFailed:
            Button("OK", role: .cancel) { }
        }
    }

    func alertMessage(for alert: AttendeeListAlert) -> Text {
        switch alert {
        case .confirmReset:
            Text("参加者リストを全員削除してもよろしいですか？")
        case .favoriteLimitReached(let currentCount, let limit):
            Text("保存できるグループは最大\(limit)個までとなっています（現在\(currentCount)個）。新しいグループを保存するには、お気に入り一覧から既存のグループを削除してください。")
        case .saveFailed(let message):
            Text(message)
        }
    }
}

private extension AttendeeListView {
    var emptyContent: some View {
        VStack(spacing: 24) {
            inputSection
            EmptyStateView(
                systemImage: "person.3.fill",
                message: String(localized: "参加者を追加してください"),
                imageFont: .system(size: 80),
                imageColor: .sakuttoBlueStart.opacity(0.3),
                spacing: AppSpacing.emptyStateSpacing
            )
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var inputSection: some View {
        HStack {
            TextField("参加者の名前を入力", text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit { addAttendeeProcess() }
                .submitLabel(.done)
                .accessibilityLabel(String(localized: "参加者の名前"))
                .accessibilityHint(String(localized: "追加する参加者の名前を入力します"))

            Button(action: addAttendeeProcess) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(newName.isEmpty ? .gray.opacity(0.4) : .sakuttoBlueStart)
            }
            .disabled(newName.isEmpty)
            .accessibilityLabel(String(localized: "参加者を追加"))
            .accessibilityHint(String(localized: "入力した名前をリストに追加します"))
        }
        .padding()
    }

    var attendeeList: some View {
        List {
            ForEach(presenter.viewData.rows) { row in
                NumberedPersonRow(number: row.number, name: row.name)
            }
            .onDelete { offsets in
                presenter.didDeleteAttendees(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
    }

    var seatingDisabled: Bool {
        !presenter.viewData.canStartSeating || !newName.isEmpty
    }

    var bottomChromeBar: some View {
        VStack(spacing: 0) {
            shuffleButton
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.bottomChromeTop)
                .padding(.bottom, 8)

            AdBannerContainer()
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    var shuffleButton: some View {
        VStack(spacing: AppSpacing.ctaStackSpacing) {
            actionButtons

            VStack(spacing: AppSpacing.ctaStackSpacing) {
                Button {
                    isTextFieldFocused = false
                    presenter.didTapSeatingChart()
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("座席表で決める")
                    }
                }
                .buttonStyle(SakuttoPrimaryButtonStyle())
                .disabled(seatingDisabled)
                .accessibilityHint(String(localized: "参加者の座席表を開きます"))

                Button {
                    isTextFieldFocused = false
                    presenter.didTapSimpleShuffle()
                } label: {
                    HStack {
                        Image(systemName: "list.number")
                        Text("番号札で決める（シンプル）")
                    }
                }
                .buttonStyle(SakuttoSecondaryButtonStyle())
                .disabled(seatingDisabled)
                .accessibilityHint(String(localized: "番号札画面を開きます"))
            }
            .opacity(seatingDisabled ? 0.5 : 1.0)
        }
    }

    var actionButtons: some View {
        ActionButtonsView(
            button1: .init(
                title: String(localized: "お気に入り"),
                icon: "star.fill",
                color: .orange,
                action: {
                    isTextFieldFocused = false
                    presenter.didTapShowFavorites()
                },
                accessibilityHint: String(localized: "保存済みグループの一覧を開きます")
            ),
            button2: .init(
                title: String(localized: "一括入力"),
                icon: "list.star",
                color: .blue,
                action: {
                    isTextFieldFocused = false
                    presenter.didTapBulkAddEntry()
                },
                accessibilityHint: String(localized: "複数の参加者をまとめて追加します")
            ),
            button3: .init(
                title: String(localized: "保存"),
                icon: "square.and.arrow.down",
                color: .green,
                action: {
                    isTextFieldFocused = false
                    groupName = ""
                    presenter.didTapSaveFavorite()
                },
                isDisabled: !presenter.viewData.canSaveFavorite,
                accessibilityHint: String(localized: "現在の参加者をお気に入りに保存します")
            ),
            button4: .init(
                title: String(localized: "削除"),
                icon: "trash",
                color: .red,
                action: {
                    presenter.didTapReset()
                },
                isDisabled: !presenter.viewData.canReset,
                accessibilityHint: String(localized: "参加者を全員削除します")
            )
        )
    }

    func addAttendeeProcess() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        newName = ""
        presenter.didTapAdd(name: trimmedName)
        isTextFieldFocused = true
    }
}

#if DEBUG
private enum AttendeeListPreviewSupport {
    @MainActor
    static func makePresenter() -> AttendeeListPresenter {
        let interactor = AttendeeListInteractor() // Preview は InMemory。実 SwiftData には触れない。
        _ = interactor.add(fromText: "太郎,花子,次郎")
        return AttendeeListPresenter(interactor: interactor, router: AttendeeListRouter())
    }
}

#Preview("参加者リスト") {
    NavigationStack {
        AttendeeListView(presenter: AttendeeListPreviewSupport.makePresenter())
    }
}
#endif
