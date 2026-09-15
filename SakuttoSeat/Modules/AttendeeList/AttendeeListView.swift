//
//  AttendeeListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 6（DesignSystem / safeAreaInset / A11y / キーボード）
//  refactor_Ad.md Phase 5（バナー余白は AdBannerContainer 内）
//  リワード復帰では空のとき以外キーボードを出さない。ボトムクロムは geometryGroup で祖先アニメーションから切り離す。
//  refactor_groupFavorite.md Phase 4（View は ModelContext / Gateway を知らない）
//  v2.1 UI/UX（未確定名でも CTA、＋のヒット領域）
//

import SwiftUI
import UIKit

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
            .background {
                Color(.systemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissKeyboard() }
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
                presenter.makeRouteSheet(route)
            }
            .onChange(of: presenter.viewData.inputNonce) { _, _ in
                newName = ""
            }
            .onChange(of: presenter.viewData.addControl) { _, control in
                if control == .hardLimited {
                    newName = ""
                    dismissKeyboard()
                }
            }
            .onChange(of: presenter.route) { _, newRoute in
                if newRoute != nil {
                    dismissKeyboard()
                }
            }
            .onAppear {
                presenter.onAppear()
                isTextFieldFocused = presenter.viewData.shouldFocusNameField
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
        case .adNotReady:
            return RewardedAdCopy.notReadyTitle
        case .attendeeUnlock:
            return VenueExpansionCopy.attendeeUnlockTitle
        case .attendeeHardLimit:
            return VenueExpansionCopy.hardLimitTitle
        case .attendeeHardLimitOverflow:
            return VenueExpansionCopy.hardLimitOverflowTitle
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
        case .favoriteLimitReached:
            Button("OK", role: .cancel) {
                presenter.didCancelFavoriteLimit()
            }
            Button(String(localized: "動画を見て1枠追加（今回だけ）")) {
                presenter.didConfirmWatchAd()
            }
        case .saveFailed, .adNotReady, .attendeeHardLimit, .attendeeHardLimitOverflow:
            Button(VenueExpansionCopy.ok, role: .cancel) { }
        case .attendeeUnlock:
            Button(VenueExpansionCopy.later, role: .cancel) { }
            Button(VenueExpansionCopy.attendeeUnlockPrimary) {
                presenter.didConfirmWatchVenueAd()
            }
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
        case .adNotReady:
            Text(RewardedAdCopy.notReadyMessage)
        case .attendeeUnlock(let overflowTotal, let remainingFree, let remainingHard):
            if let overflowTotal, let remainingFree, let remainingHard {
                Text(VenueExpansionCopy.attendeeOverflowMessage(
                    triedCount: overflowTotal,
                    remainingFree: remainingFree,
                    remainingHard: remainingHard
                ))
            } else {
                Text(VenueExpansionCopy.attendeeUnlockMessage)
            }
        case .attendeeHardLimit:
            Text(VenueExpansionCopy.attendeeHardLimitMessage)
        case .attendeeHardLimitOverflow(let triedCount, let remainingHard):
            Text(VenueExpansionCopy.attendeeHardLimitOverflowMessage(
                triedCount: triedCount,
                remainingHard: remainingHard
            ))
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
                imageColor: .sakuttoBlueStart.opacity(0.3),
                spacing: AppSpacing.emptyStateSpacing
            )
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var inputSection: some View {
        HStack {
            TextField(nameFieldPlaceholder, text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .disabled(isAttendeeHardLimited)
                .onSubmit { addAttendeeProcess() }
                .submitLabel(.join)
                .accessibilityLabel(String(localized: "参加者の名前"))
                .accessibilityHint(nameFieldAccessibilityHint)

            Button(action: addAttendeeProcess) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(addButtonForeground)
                        .opacity(addButtonOpacity)
                    if presenter.viewData.addControl == .needsUnlock {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .offset(x: 2, y: 2)
                    }
                }
                .frame(minWidth: AppSpacing.minTapTarget, minHeight: AppSpacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .disabled(newName.isEmpty || isAttendeeHardLimited)
            .accessibilityLabel(String(localized: "参加者を追加"))
            .accessibilityHint(addButtonAccessibilityHint)
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
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                isTextFieldFocused = false
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 16).onChanged { _ in
                guard isTextFieldFocused else { return }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                isTextFieldFocused = false
            }
        )
        .scrollContentBackground(.hidden)
        .background {
            Color(.systemGroupedBackground)
                .onTapGesture { dismissKeyboard() }
        }
    }

    var seatingDisabled: Bool {
        !presenter.viewData.canStartSeating && pendingName.isEmpty
    }

    /// 未確定入力。CTA はこれがあるときも押せる。
    var pendingName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var bottomChromeBar: some View {
        VStack(spacing: 0) {
            shuffleButton
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.bottomChromeTop)
                .padding(.bottom, 8)

            if !isTextFieldFocused {
                AdBannerContainer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, y: -3)
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture { dismissKeyboard() }
        )
        // リワード復帰やキーボード inset の祖先アニメーションから切り離し、CTA+バナーのクリップ→復帰を防ぐ。
        .geometryGroup()
        .animation(nil, value: presenter.viewData.addControl)
        .animation(nil, value: presenter.viewData.rows.count)
    }

    var shuffleButton: some View {
        VStack(spacing: AppSpacing.ctaStackSpacing) {
            actionButtons

            VStack(spacing: AppSpacing.ctaStackSpacing) {
                Button {
                    startSeating { presenter.didTapSeatingChart() }
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
                    startSeating { presenter.didTapSimpleShuffle() }
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
                isDisabled: isAttendeeHardLimited,
                accessibilityHint: isAttendeeHardLimited
                    ? VenueExpansionCopy.attendeeHardLimitMessage
                    : String(localized: "複数の参加者をまとめて追加します")
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

    var isAttendeeHardLimited: Bool {
        presenter.viewData.addControl == .hardLimited
    }

    var nameFieldPlaceholder: String {
        isAttendeeHardLimited
            ? VenueExpansionCopy.attendeeInputHardLimitPlaceholder
            : String(localized: "参加者の名前を入力")
    }

    var nameFieldAccessibilityHint: String {
        isAttendeeHardLimited
            ? VenueExpansionCopy.attendeeHardLimitMessage
            : String(localized: "追加する参加者の名前を入力します")
    }

    var addButtonForeground: Color {
        if newName.isEmpty {
            return .gray.opacity(0.4)
        }
        switch presenter.viewData.addControl {
        case .available:
            return .sakuttoBlueStart
        case .needsUnlock:
            return .secondary
        case .hardLimited:
            return .sakuttoBlueStart
        }
    }

    var addButtonOpacity: Double {
        presenter.viewData.addControl == .hardLimited ? 0.35 : 1
    }

    var addButtonAccessibilityHint: String {
        switch presenter.viewData.addControl {
        case .available:
            return String(localized: "入力した名前をリストに追加します")
        case .needsUnlock:
            return String(localized: "動画を見ると人数を追加できます")
        case .hardLimited:
            return String(localized: "これ以上は追加できません")
        }
    }

    func addAttendeeProcess() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if presenter.didTapAdd(name: trimmedName) {
            newName = ""
        }
        isTextFieldFocused = true
    }

    /// 未確定名があれば先に追加する。解放やハード上限なら遷移しない。
    func startSeating(_ start: () -> Void) {
        isTextFieldFocused = false
        if pendingName.isEmpty {
            start()
            return
        }
        if presenter.didTapAdd(name: pendingName) {
            newName = ""
            start()
        }
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isTextFieldFocused = false
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
