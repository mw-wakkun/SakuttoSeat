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
    @State private var editingTableIndex: Int? = nil
    @State private var isShowingSaveAlert = false
    @State private var templateName = ""
    @State private var isShowingTemplateList = false
    @State private var showTemplateLimitAlert = false
    // MARK: - アンロック・広告管理
    @StateObject private var adManager = RewardedAdManager.shared
    
    @State private var showingUnlockSheet = false
    @State private var showingSettingsSheet = false
    @State private var shouldShowAdOnDismiss = false
    @State private var showingShareOptions = false
    @State private var pendingShareSelection: ShareSelectionKind?
    @State private var showingImageShareAdAlert = false
    @State private var showingAdNotReadyAlert = false
    // 会場全体のテーブル列数設定（最大10列まで）
    @State private var globalTableColumnCount: Int = 2
    // セッション限定：3列以上のレイアウト解放フラグ（アプリ終了時にリセット）
    @State private var sessionUnlockedColumns: Bool = false
    private let scrollAnchorTopID = "SeatingChartScrollTop"
    /// 最下部テーブルとアクションバーのあいだに確保する余白
    private let scrollBottomBreathingRoom: CGFloat = 32
    
    // グリッド幅の計算（最小幅を確保）
    private var gridMinWidth: CGFloat {
        let tableMinWidth: CGFloat = 140 + 16 // テーブル最小幅 + スペーシング
        return tableMinWidth * CGFloat(globalTableColumnCount) + 32 // パディング分
    }
    
    /// テーブルを会場列数ごとの行に分割（末尾に「テーブル追加」ボタン用の枠を1つ足す）
    private var tableGridRows: [[SeatingChartGridItem]] {
        var items: [SeatingChartGridItem] = presenter.tables.indices.map { .table($0) }
        items.append(.addButton)
        let columnCount = max(1, globalTableColumnCount)
        return stride(from: 0, to: items.count, by: columnCount).map { start in
            Array(items[start..<min(start + columnCount, items.count)])
        }
    }
    
    // 座席表 Result を共有するためのテキスト組み立て（列数に対応）
    private var shareText: String {
        var text = "【サクッと席決め】座席表のシャッフル結果です！\n\n"
        
        for table in presenter.tables {
            text += "━━━━━━━━━━━━━━━━━\n"
            text += "▼ \(table.name)\n"
            text += "━━━━━━━━━━━━━━━━━\n"
            
            let members = table.assignedMembers
            let colCount = max(1, table.columnCount)
            
            if members.isEmpty {
                text += "（まだメンバーが配置されていません）\n"
            } else {
                for (index, member) in members.enumerated() {
                    let row = (index / colCount) + 1
                    let col = (index % colCount) + 1
                    
                    if colCount == 2 {
                        let side = (index % 2 == 0) ? "左" : "右"
                        text += "🪑 [\(row)列目 · \(side)] : \(member.name)\n"
                    } else {
                        text += "🪑 [\(row)行\(col)列目] : \(member.name)\n"
                    }
                }
            }
            text += "\n"
        }
        
        text += "#サクッと席決め"
        return text
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            // 双方向 ScrollView は safeAreaInset を無視しやすく末尾が見切れるため、
            // 縦スクロールを外側・横スクロールを内側に分離する
            ScrollView(.vertical) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(scrollAnchorTopID)
                        
                        // LazyVGrid は高さを過小評価し、末尾テーブルが見切れるため
                        // 明示的な VStack / HStack で全高さを即時計算する
                        VStack(alignment: .center, spacing: 16) {
                            ForEach(Array(tableGridRows.enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(row) { item in
                                        switch item {
                                        case .table(let idx):
                                            let table = presenter.tables[idx]
                                            SeatingTableView(table: table, presenter: presenter, onEditTarget: {
                                                editingTableIndex = idx
                                            })
                                            .frame(minWidth: 140)
                                            .frame(maxWidth: .infinity, alignment: .top)
                                        case .addButton:
                                            Button(action: {
                                                presenter.addTable()
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
                                    
                                    // 行の末尾が列数に満たない場合、幅を揃えるためのスペーサー
                                    let fillCount = max(0, globalTableColumnCount - row.count)
                                    ForEach(0..<fillCount, id: \.self) { _ in
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
                        // 画面より狭いときは親幅いっぱいに広げて中央配置、
                        // 列が多いときは minWidth で横スクロール可能にする
                        .frame(minWidth: gridMinWidth)
                        .containerRelativeFrame(.horizontal, alignment: .center) { length, _ in
                            max(length, gridMinWidth)
                        }
                    }
                }
                // 横 ScrollView が縦方向を縮めないよう、内容の高さに合わせる
                .fixedSize(horizontal: false, vertical: true)
                // safeAreaInset でバー分は確保済み。最下部の見切れ防止に少し余白を足す
                .padding(.bottom, scrollBottomBreathingRoom)
            }
            .onChange(of: presenter.scrollToTopTrigger) { _, _ in
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
                Button(action: { showingSettingsSheet = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsSheetView(globalTableColumnCount: $globalTableColumnCount, sessionUnlockedColumns: $sessionUnlockedColumns, adManager: adManager)
                .presentationDetents([.medium])
        }
        // テンプレート保存用アラート
        .alert("レイアウトを保存", isPresented: $isShowingSaveAlert) {
            TextField("テンプレート名 (例: デフォルト設定)", text: $templateName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                presenter.saveLayoutAsTemplate(templateName: templateName, globalColumnCount: globalTableColumnCount, context: modelContext)
            }
        } message: {
            Text("現在のテーブル構成をテンプレートとして保存します。")
        }
        .sheet(isPresented: Binding(get: { editingTableIndex != nil }, set: { newVal in if !newVal { editingTableIndex = nil } })) {
            if let idx = editingTableIndex, presenter.tables.indices.contains(idx) {
                TableEditView(table: presenter.tables[idx], presenter: presenter)
            }
        }
        .sheet(isPresented: $isShowingTemplateList) {
            SeatingTemplateListView { selectedTemplate in
                let restoredColumnCount = presenter.applyTemplate(selectedTemplate)
                globalTableColumnCount = restoredColumnCount
            }
            .presentationDetents([.medium, .large])
        }
        .alert("テンプレート上限", isPresented: $showTemplateLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("保存できるテンプレートは最大3個までとなっています。新しいテンプレートを保存するには、テンプレート読込一覧から既存のテンプレートを削除してください。")
        }
        .sheet(isPresented: $showingShareOptions, onDismiss: {
            guard let pendingShareSelection else { return }
            self.pendingShareSelection = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                switch pendingShareSelection {
                case .text:
                    presentShareSheet(with: shareText)
                case .image:
                    handleImageShareTapped()
                }
            }
        }) {
            ShareSelectionView { kind in
                pendingShareSelection = kind
            }
        }
        .alert("画像で共有", isPresented: $showingImageShareAdAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("OK") {
                playRewardedAdThenShareImage()
            }
        } message: {
            Text("動画広告を視聴して画像を出力しますか？")
        }
        .alert("広告を読み込み中", isPresented: $showingAdNotReadyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
        }
        .sheet(isPresented: $showingUnlockSheet, onDismiss: {
            if shouldShowAdOnDismiss {
                shouldShowAdOnDismiss = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    adManager.showAd {
                        sessionUnlockedColumns = true
                        isShowingSaveAlert = true
                    }
                }
            }
        }) {
            UnlockSheetView {
                shouldShowAdOnDismiss = true
            }
        }
    }
}

extension SeatingChartView {
    
    private var bottomChromeBar: some View {
        VStack(spacing: 8) {
            ActionButtonsView(
                button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                    isShowingTemplateList = true
                }),
                button2: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                    templateName = ""
                    if presenter.canSaveTemplate(context: modelContext) {
                        isShowingSaveAlert = true
                    } else {
                        showingUnlockSheet = true
                    }
                }, isDisabled: presenter.tables.isEmpty),
                button3: .init(title: "共有", icon: "square.and.arrow.up", color: .blue, action: {
                    showingShareOptions = true
                }, isDisabled: presenter.tables.isEmpty),
                button4: .init(title: "シャッフル", icon: "shuffle", color: .purple, action: {
                    presenter.shuffle()
                })
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
    
    private func handleImageShareTapped() {
        // 画像出力は常にリワード広告の視聴を必要とする
        showingImageShareAdAlert = true
    }
    
    private func playRewardedAdThenShareImage() {
        guard adManager.isAdReady else {
            adManager.loadAd()
            showingAdNotReadyAlert = true
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            adManager.showAd {
                exportAndShareSeatingChartImage()
            }
        }
    }
    
    @MainActor
    private func exportAndShareSeatingChartImage() {
        // 会場列数とテーブル数から出力サイズを算出する
        let screenWidth = UIScreen.main.bounds.width
        let tableWidth: CGFloat = 140 // スナップショットで使う固定幅
        let tableSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 32
        
        // 会場列数から横幅を求める
        let tableCount = CGFloat(globalTableColumnCount)
        let calculatedWidth = tableCount * tableWidth + (tableCount - 1) * tableSpacing + horizontalPadding
        let exportWidth = max(screenWidth, calculatedWidth)
        
        // テーブルの行数から高さを求める
        let tableHeight: CGFloat = 150 // テーブル1つあたりの推定高さ
        let verticalSpacing: CGFloat = 16
        let verticalPadding: CGFloat = 32
        let tableRowCount = ceil(CGFloat(presenter.tables.count) / CGFloat(globalTableColumnCount))
        let calculatedHeight = tableRowCount * (tableHeight + verticalSpacing) + verticalPadding
        let exportHeight = max(400, calculatedHeight) // 最低の高さは400
        
        // 固定サイズを与えて出力用ビューを組み立てる
        let exportView = SeatingChartSnapshotView(tables: presenter.tables, globalColumnCount: globalTableColumnCount)
            .frame(width: exportWidth, height: exportHeight, alignment: .topLeading)
            .background(Color(.systemBackground))
        
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: exportHeight)
        
        guard let image = renderer.uiImage else { return }
        presentShareSheet(with: image)
    }
    
    // シェアシートを呼び出す
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
