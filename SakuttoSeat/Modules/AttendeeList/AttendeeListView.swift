//
//  AttendeeListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 2（route / viewData への集約）
//

import SwiftUI
import SwiftData

struct AttendeeListView: View {
    @StateObject var presenter: AttendeeListPresenter
    /// 未確定のキー入力。確定時だけ Presenter へ渡す
    @State private var newName = ""
    /// 保存アラートの TextField 用（route が `.saveFavoritePrompt` のときだけ使う）
    @State private var groupName = ""
    /// 一括追加は Phase 5 で子モジュールへ移すまでの一時入力
    @State private var bulkInputText = ""
    @FocusState private var isTextFieldFocused: Bool

    /// SwiftData の制約上、実 Gateway は初回 `onAppear` で渡す（SeatingChart と同じ過渡期）。
    /// View は Entity / `@Query` を持たない。保持は Interactor。
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if presenter.viewData.isEmpty {
                        Spacer()
                        VStack(spacing: 24) {
                            inputSection
                            emptyStateView
                                .padding(.horizontal, 24)
                        }
                        Spacer()
                    } else {
                        inputSection
                        attendeeList
                    }
                    Spacer()
                        .frame(height: presenter.viewData.isEmpty ? 200 : 240)
                }

                VStack(spacing: 0) {
                    shuffleButton
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background(Color(.systemBackground).opacity(0.9))

                    AdBannerView()
                        .frame(width: 320, height: 50)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                }
            }
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
                sheetContent(for: route)
            }
            .onAppear {
                presenter.attachFavoriteGateway(SwiftDataGroupFavoriteGateway(context: modelContext))
                presenter.onAppear()
                isTextFieldFocused = true
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationDestination(item: navigationRouteBinding) { route in
                presenter.view(for: route)
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
            return "参加者のリセット"
        case .favoriteLimitReached:
            return "お気に入り上限"
        case .saveFailed:
            return "保存に失敗しました"
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

// MARK: - サブビュー（お気に入り関連・一括追加）
// Phase 5 で FavoriteGroup / BulkAdd 子モジュールへ切り出す。

private extension AttendeeListView {
    @ViewBuilder
    func sheetContent(for route: AttendeeListRoute) -> some View {
        switch route {
        case .favoriteList:
            favoriteGroupSheetView
        case .bulkAdd:
            bulkAddSheetView
        case .seatingChart, .simpleShuffle, .saveFavoritePrompt, .alert:
            EmptyView()
        }
    }

    var bulkAddSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("改行またはカンマ（、）区切りで参加者名を入力・ペーストしてください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $bulkInputText)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()
            .navigationTitle("参加者の一括追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        bulkInputText = ""
                        presenter.dismissRoute()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        presenter.didTapBulkAdd(text: bulkInputText)
                        bulkInputText = ""
                    }
                    .disabled(bulkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    var favoriteGroupSheetView: some View {
        NavigationStack {
            Group {
                List {
                    if presenter.viewData.favoriteGroups.isEmpty {
                        Section {
                            VStack(spacing: 16) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("登録されているグループはありません")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .listRowInsets(EdgeInsets())
                        }
                    } else {
                        Section {
                            ForEach(presenter.viewData.favoriteGroups) { group in
                                Button(action: {
                                    presenter.didSelectFavoriteGroup(id: group.id)
                                }) {
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
                                presenter.didDeleteFavoriteGroups(at: offsets)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("お気に入りグループ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { presenter.dismissRoute() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension AttendeeListView {
    var inputSection: some View {
        HStack {
            TextField("参加者の名前を入力", text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit { addAttendeeProcess() }
                .submitLabel(.done)

            Button(action: addAttendeeProcess) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(newName.isEmpty ? .gray.opacity(0.4) : .sakuttoBlueStart)
            }
            .disabled(newName.isEmpty)
        }
        .padding()
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(.sakuttoBlueStart.opacity(0.3))

            Text("参加者を追加してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    var attendeeList: some View {
        List {
            ForEach(presenter.viewData.rows) { row in
                AttendeeRow(number: row.number, name: row.name)
            }
            .onDelete { offsets in
                presenter.didDeleteAttendees(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }

    var seatingDisabled: Bool {
        !presenter.viewData.canStartSeating || !newName.isEmpty
    }

    var shuffleButton: some View {
        VStack(spacing: 12) {
            actionButtons

            VStack(spacing: 12) {
                Button(action: {
                    isTextFieldFocused = false
                    presenter.didTapSeatingChart()
                }) {
                    buttonLabel(text: "座席表で決める", icon: "square.grid.2x2.fill", isPrimary: true)
                }
                .disabled(seatingDisabled)

                Button(action: {
                    isTextFieldFocused = false
                    presenter.didTapSimpleShuffle()
                }) {
                    buttonLabel(text: "番号札で決める（シンプル）", icon: "list.number", isPrimary: false)
                }
                .disabled(seatingDisabled)
            }
            .opacity(seatingDisabled ? 0.5 : 1.0)
        }
    }

    var actionButtons: some View {
        ActionButtonsView(
            button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                isTextFieldFocused = false
                presenter.didTapShowFavorites()
            }),
            button2: .init(title: "一括入力", icon: "list.star", color: .blue, action: {
                isTextFieldFocused = false
                presenter.didTapBulkAddEntry()
            }),
            button3: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                isTextFieldFocused = false
                groupName = ""
                presenter.didTapSaveFavorite()
            }, isDisabled: !presenter.viewData.canSaveFavorite),
            button4: .init(title: "削除", icon: "trash", color: .red, action: {
                presenter.didTapReset()
            }, isDisabled: !presenter.viewData.canReset)
        )
    }

    private func buttonLabel(text: String, icon: String, isPrimary: Bool) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.headline).bold()
        .foregroundColor(isPrimary ? .white : .blue)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            isPrimary ?
            AnyView(Color.sakuttoGradient) :
                AnyView(Color.blue.opacity(0.1))
        )
        .cornerRadius(15)
        .shadow(
            color: (isPrimary ? Color.sakuttoBlueStart : Color.blue).opacity(0.3),
            radius: 8, x: 0, y: 4
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
        let interactor = AttendeeListInteractor()
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
