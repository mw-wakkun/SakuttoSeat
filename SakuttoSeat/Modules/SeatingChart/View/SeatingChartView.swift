//
//  SeatingChartView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import SwiftData

struct SeatingChartView: View {
    @StateObject var presenter: SeatingChartPresenter
    @Environment(\.modelContext) private var modelContext
    @StateObject private var adManager = RewardedAdManager.shared
    /// 保存アラートの TextField 用（route が `.saveTemplatePrompt` のときだけ使う）
    @State private var templateName = ""

    private let scrollAnchorTopID = "SeatingChartScrollTop"
    private let scrollBottomBreathingRoom: CGFloat = 32

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
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.largeTitle)
                                                    Text("テーブル追加")
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(minHeight: 120)
                                                .background(Color.secondary.opacity(0.1))
                                                .cornerRadius(12)
                                            }
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
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .frame(minWidth: presenter.viewData.minGridWidth)
                        .containerRelativeFrame(.horizontal, alignment: .center) { length, _ in
                            max(length, presenter.viewData.minGridWidth)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
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
            bottomChromeBar
        }
        .background(Color(.systemBackground))
        .navigationTitle("座席表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { presenter.didTapSettings() }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .sheet(item: sheetRouteBinding) { route in
            sheetContent(for: route)
        }
        .alert("レイアウトを保存", isPresented: savePromptBinding) {
            TextField("テンプレート名 (例: デフォルト設定)", text: $templateName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                presenter.didConfirmSaveTemplate(name: templateName, context: modelContext)
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
        case .confirmImageShareWithAd:
            return "画像で共有"
        case .adNotReady:
            return "広告を読み込み中"
        case .requireUnlockForColumns:
            return "アンロックが必要です"
        case .saveFailed:
            return "保存に失敗しました"
        case .imageExportFailed:
            return "画像出力に失敗しました"
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
    func sheetContent(for route: SeatingChartRoute) -> some View {
        switch route {
        case .tableEdit(let tableID):
            TableEditView(tableID: tableID, presenter: presenter)
        case .venueSettings:
            SettingsSheetView(
                globalTableColumnCount: $presenter.globalColumnCount,
                sessionUnlockedColumns: $presenter.sessionUnlockedColumns,
                adManager: adManager
            )
            .presentationDetents([.medium])
        case .templateList:
            SeatingTemplateListView { selectedTemplate in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    presenter.didSelectTemplate(selectedTemplate)
                }
            }
            .presentationDetents([.medium, .large])
        case .shareSelection:
            ShareSelectionView { kind in
                presenter.didSelectShareKind(kind)
            }
            .onDisappear {
                guard let pending = presenter.pendingShareSelection else { return }
                presenter.pendingShareSelection = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    switch pending {
                    case .text:
                        presentShareSheet(with: presenter.makeShareText())
                    case .image:
                        presenter.didRequestImageShare()
                    }
                }
            }
        case .unlockForSave:
            UnlockSheetView {
                presenter.shouldShowAdOnDismiss = true
            }
            .onDisappear {
                guard presenter.shouldShowAdOnDismiss else { return }
                presenter.shouldShowAdOnDismiss = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    adManager.showAd {
                        presenter.sessionUnlockedColumns = true
                        presenter.route = .saveTemplatePrompt
                    }
                }
            }
        case .saveTemplatePrompt, .alert:
            EmptyView()
        }
    }

    @ViewBuilder
    func alertButtons(for alert: SeatingChartAlert) -> some View {
        switch alert {
        case .templateLimitReached:
            Button("OK", role: .cancel) { }
        case .confirmImageShareWithAd:
            Button("キャンセル", role: .cancel) { }
            Button("OK") {
                let isReady = adManager.isAdReady
                if !isReady {
                    adManager.loadAd()
                }
                presenter.didConfirmImageShareWithAd(isAdReady: isReady) {
                    adManager.showAd {
                        exportAndShareSeatingChartImage()
                    }
                }
            }
        case .adNotReady:
            Button("OK", role: .cancel) { }
        case .requireUnlockForColumns:
            Button("OK", role: .cancel) { }
        case .saveFailed:
            Button("OK", role: .cancel) { }
        case .imageExportFailed:
            Button("OK", role: .cancel) { }
        }
    }

    func alertMessage(for alert: SeatingChartAlert) -> Text {
        switch alert {
        case .templateLimitReached(let currentCount, let limit):
            Text("保存できるテンプレートは最大\(limit)個までとなっています（現在\(currentCount)個）。新しいテンプレートを保存するには、テンプレート読込一覧から既存のテンプレートを削除してください。")
        case .confirmImageShareWithAd:
            Text("動画広告を視聴して画像を出力しますか？")
        case .adNotReady:
            Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
        case .requireUnlockForColumns(let requested):
            Text("\(requested)列以上のレイアウトを利用するには動画広告の視聴が必要です。")
        case .saveFailed(let message):
            Text(message)
        case .imageExportFailed:
            Text("画像の出力に失敗しました。もう一度お試しください。")
        }
    }
}

extension SeatingChartView {

    private var bottomChromeBar: some View {
        VStack(spacing: 8) {
            ActionButtonsView(
                button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                    presenter.didTapLoadTemplate()
                }),
                button2: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                    templateName = ""
                    presenter.didTapSaveTemplate(canSave: presenter.canSaveTemplate(context: modelContext))
                }, isDisabled: !presenter.viewData.isSaveEnabled),
                button3: .init(title: "共有", icon: "square.and.arrow.up", color: .blue, action: {
                    presenter.didTapShare()
                }, isDisabled: !presenter.viewData.isShareEnabled),
                button4: .init(title: "シャッフル", icon: "shuffle", color: .purple, action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        presenter.didTapShuffle()
                    }
                }, isDisabled: !presenter.viewData.isShuffleEnabled)
            )
            .padding(.horizontal, 16)

            AdBannerView()
                .frame(width: 320, height: 50)
                .padding(.bottom, 4)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @MainActor
    private func exportAndShareSeatingChartImage() {
        let screenWidth = UIScreen.main.bounds.width
        let tableWidth: CGFloat = 140
        let tableSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 32

        let tableCount = CGFloat(presenter.viewData.globalColumnCount)
        let calculatedWidth = tableCount * tableWidth + (tableCount - 1) * tableSpacing + horizontalPadding
        let exportWidth = max(screenWidth, calculatedWidth)

        let tableHeight: CGFloat = 150
        let verticalSpacing: CGFloat = 16
        let verticalPadding: CGFloat = 32
        let tableOnlyCount = presenter.viewData.rows.reduce(0) { partial, row in
            partial + row.items.filter {
                if case .table = $0 { return true }
                return false
            }.count
        }
        let tableRowCount = ceil(CGFloat(tableOnlyCount) / CGFloat(presenter.viewData.globalColumnCount))
        let calculatedHeight = tableRowCount * (tableHeight + verticalSpacing) + verticalPadding
        let exportHeight = max(400, calculatedHeight)

        let exportView = SeatingChartSnapshotView(viewData: presenter.viewData)
            .frame(width: exportWidth, height: exportHeight, alignment: .topLeading)
            .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: exportHeight)

        guard let image = renderer.uiImage else {
            presenter.route = .alert(.imageExportFailed)
            return
        }
        presentShareSheet(with: image)
    }

    private func presentShareSheet(with item: Any) {
        guard let topViewController = UIApplication.shared.topViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = topViewController.view
            popoverController.sourceRect = CGRect(x: topViewController.view.bounds.midX, y: topViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        topViewController.present(activityVC, animated: true, completion: nil)
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
