//
//  SeatingChartView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//  refactor_Ad.md Phase 5（バナー余白は AdBannerContainer 内。上下とも同じトークン）
//  View は ModelContext / Gateway を知らない。assemble 時点で注入済み。
//  v2.1 Phase 3（発表はナビ左。Cover 中はバナー inset を外す）
//  v2.1 UI/UX（発表ツールバーにラベル、無効時 Hint）
//  v2.1 UI/UX（会場設定・卓追加・下段の A11y 名）
//

import SwiftUI

struct SeatingChartView: View {
    @StateObject var presenter: SeatingChartPresenter
    /// 保存アラートの TextField 用（route が `.saveTemplatePrompt` のときだけ使う）
    @State private var templateName = ""

    private let scrollAnchorTopID = "SeatingChartScrollTop"
    private let scrollBottomBreathingRoom: CGFloat = 32
    /// 横 ScrollView は内容の理想高さを返さないことがある。定員が増えたテーブルが重ならないよう実測する。
    @State private var canvasContentHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(scrollAnchorTopID)

                        VStack(alignment: .center, spacing: 16) {
                            ForEach(presenter.viewData.rows) { row in
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(row.items) { item in
                                        switch item {
                                        case .table(let table):
                                            SeatingTableView(
                                                table: table,
                                                onEditTarget: {
                                                    presenter.didTapTable(id: table.id)
                                                },
                                                onTapSeat: { memberID in
                                                    presenter.didTapSeat(tableID: table.id, memberID: memberID)
                                                }
                                            )
                                            .frame(minWidth: 140)
                                            .frame(maxWidth: .infinity, alignment: .top)
                                        case .addButton:
                                            Button(action: {
                                                presenter.didTapAddTable()
                                            }) {
                                                VStack {
                                                    ZStack(alignment: .bottomTrailing) {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.largeTitle)
                                                        if presenter.viewData.showsAddTableUnlockBadge {
                                                            Image(systemName: "play.rectangle.fill")
                                                                .font(.caption)
                                                                .foregroundStyle(.secondary)
                                                                .offset(x: 6, y: 4)
                                                        }
                                                    }
                                                    Text(SeatingChartCopy.addTableTitle)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(minHeight: 120)
                                                .background(Color.secondary.opacity(0.1))
                                                .cornerRadius(12)
                                            }
                                            .accessibilityLabel(SeatingChartCopy.addTableAccessibilityLabel)
                                            .modifier(
                                                OptionalAccessibilityHint(
                                                    hint: presenter.viewData.showsAddTableUnlockBadge
                                                        ? SeatingChartCopy.addTableUnlockHint
                                                        : nil
                                                )
                                            )
                                            .frame(minWidth: 140)
                                            .frame(maxWidth: .infinity, alignment: .top)
                                        }
                                    }

                                    ForEach(0..<row.trailingFillerCount, id: \.self) { _ in
                                        Color.clear
                                            .frame(minWidth: 140)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }

                            if let caption = presenter.viewData.tableLimitCaption {
                                Text(caption)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .frame(minWidth: presenter.viewData.minGridWidth)
                        .containerRelativeFrame(.horizontal, alignment: .center) { length, _ in
                            max(length, presenter.viewData.minGridWidth)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: CanvasContentHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                }
                .onPreferenceChange(CanvasContentHeightKey.self) { canvasContentHeight = $0 }
                .frame(height: canvasContentHeight > 0 ? canvasContentHeight : nil, alignment: .top)
                .padding(.bottom, scrollBottomBreathingRoom)
            }
            .onChange(of: presenter.canvasEvent) { _, event in
                guard case .scrollToTop = event else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(scrollAnchorTopID, anchor: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isPresenting {
                bottomChromeBar
            }
        }
        .background(Color(.systemBackground))
        .background {
            InteractivePopGestureController(isEnabled: !isPresenting)
        }
        .navigationTitle("座席表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                PresentToolbarButton(
                    isEnabled: presenter.viewData.isShareEnabled,
                    accessibilityHint: presenter.viewData.isShareEnabled
                        ? PresentationCopy.presentAccessibilityHint
                        : PresentationCopy.seatingPresentDisabledHint
                ) {
                    presenter.didTapPresent()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    presenter.didTapSettings()
                } label: {
                    Label(VenueSettingsCopy.navigationTitle, systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                }
                .accessibilityHint(VenueSettingsCopy.openHint)
            }
        }
        .sheet(item: sheetRouteBinding) { route in
            presenter.makeRouteSheet(route)
        }
        .fullScreenCover(item: presentationRouteBinding) { route in
            presenter.makePresentationCover(route)
        }
        .shareFlow(presenter.share)
        .alert("レイアウトを保存", isPresented: savePromptBinding) {
            TextField("テンプレート名 (例: デフォルト設定)", text: $templateName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                presenter.didConfirmSaveTemplate(name: templateName)
            }
        } message: {
            Text("現在のテーブル構成をテンプレートとして保存します。")
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
    }
}

// MARK: - Route Bindings

private extension SeatingChartView {
    var isPresenting: Bool {
        presenter.route?.presentsAsFullScreenCover == true
    }

    var presentationRouteBinding: Binding<SeatingChartRoute?> {
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

    var sheetRouteBinding: Binding<SeatingChartRoute?> {
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

    var savePromptBinding: Binding<Bool> {
        Binding(
            get: {
                if case .saveTemplatePrompt = presenter.route { return true }
                return false
            },
            set: { isPresented in
                if !isPresented, case .saveTemplatePrompt = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var presentedAlert: SeatingChartAlert? {
        if case .alert(let alert) = presenter.route { return alert }
        return nil
    }

    var alertTitle: String {
        switch presentedAlert {
        case .templateLimitReached:
            return "テンプレート上限"
        case .saveFailed:
            return "保存に失敗しました"
        case .venueUnlock:
            return VenueExpansionCopy.venueUnlockTitle
        case .tableHardLimit, .totalSeatHardLimit:
            return VenueExpansionCopy.hardLimitTitle
        case .adNotReady:
            return RewardedAdCopy.notReadyTitle
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
    func alertButtons(for alert: SeatingChartAlert) -> some View {
        switch alert {
        case .templateLimitReached, .saveFailed, .tableHardLimit, .totalSeatHardLimit, .adNotReady:
            Button(VenueExpansionCopy.ok, role: .cancel) { }
        case .venueUnlock:
            Button(VenueExpansionCopy.later, role: .cancel) { }
            Button(VenueExpansionCopy.venueUnlockPrimary) {
                presenter.didConfirmWatchVenueAd()
            }
        }
    }

    func alertMessage(for alert: SeatingChartAlert) -> Text {
        switch alert {
        case .templateLimitReached(let currentCount, let limit):
            Text("保存できるテンプレートは最大\(limit)個までとなっています（現在\(currentCount)個）。新しいテンプレートを保存するには、テンプレート読込一覧から既存のテンプレートを削除してください。")
        case .saveFailed(let message):
            Text(message)
        case .venueUnlock:
            Text(VenueExpansionCopy.venueUnlockMessage)
        case .tableHardLimit:
            Text(VenueExpansionCopy.tableHardLimitMessage)
        case .totalSeatHardLimit:
            Text(VenueExpansionCopy.totalSeatHardLimitMessage)
        case .adNotReady:
            Text(RewardedAdCopy.notReadyMessage)
        }
    }
}

extension SeatingChartView {

    private var bottomChromeBar: some View {
        VStack(spacing: 8) {
            ActionButtonsView(
                button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                    presenter.didTapLoadTemplate()
                }, accessibilityHint: SeatingChartCopy.loadTemplateHint),
                button2: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                    templateName = ""
                    presenter.didTapSaveTemplate()
                }, isDisabled: !presenter.viewData.isSaveEnabled, accessibilityHint: SeatingChartCopy.saveHint),
                button3: .init(title: "共有", icon: "square.and.arrow.up", color: .blue, action: {
                    presenter.didTapShare()
                }, isDisabled: !presenter.viewData.isShareEnabled, accessibilityHint: SeatingChartCopy.shareHint),
                button4: .init(title: "シャッフル", icon: "shuffle", color: .purple, action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        presenter.didTapShuffle()
                    }
                }, isDisabled: !presenter.viewData.isShuffleEnabled, accessibilityHint: SeatingChartCopy.shuffleHint)
            )
            .padding(.horizontal, 16)

            AdBannerContainer()
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct CanvasContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
#Preview("座席表") {
    NavigationStack {
        SeatingChartView(
            presenter: SeatingChartPresenter(
                interactor: SeatingChartInteractor(
                    attendees: [
                        Attendee(name: "太郎"),
                        Attendee(name: "花子"),
                        Attendee(name: "次郎"),
                        Attendee(name: "三郎"),
                        Attendee(name: "四郎")
                    ]
                ),
                router: SeatingChartRouter()
            )
        )
    }
}
#endif
