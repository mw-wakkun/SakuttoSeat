//
//  SeatingChartView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import SwiftData

/// 座席表グリッドの1セル（テーブル or 追加ボタン）
private enum SeatingChartGridItem: Identifiable {
    case table(Int)
    case addButton
    
    var id: String {
        switch self {
        case .table(let index):
            return "table-\(index)"
        case .addButton:
            return "add-button"
        }
    }
}

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
        // Removed PRO gating: always use rewarded ad flow for image export
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
        // Calculate export dimensions based on global column count and table count
        let screenWidth = UIScreen.main.bounds.width
        let tableWidth: CGFloat = 140 // Fixed width as used in snapshot
        let tableSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 32
        
        // Calculate width based on global column count
        let tableCount = CGFloat(globalTableColumnCount)
        let calculatedWidth = tableCount * tableWidth + (tableCount - 1) * tableSpacing + horizontalPadding
        let exportWidth = max(screenWidth, calculatedWidth)
        
        // Calculate height based on number of table rows
        let tableHeight: CGFloat = 150 // Estimated height per table
        let verticalSpacing: CGFloat = 16
        let verticalPadding: CGFloat = 32
        let tableRowCount = ceil(CGFloat(presenter.tables.count) / CGFloat(globalTableColumnCount))
        let calculatedHeight = tableRowCount * (tableHeight + verticalSpacing) + verticalPadding
        let exportHeight = max(400, calculatedHeight) // Minimum height of 400
        
        // Build export view with fixed dimensions and proper sizing
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

// MARK: - 画像出力用スナップショット
private struct SeatingChartSnapshotView: View {
    let tables: [SeatingTable]
    let globalColumnCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(tableRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row) { table in
                        SnapshotSeatingTableView(table: table)
                            .frame(width: 140) // Fixed width for consistent table sizing
                    }
                    // Fill remaining columns with empty views to maintain grid structure
                    let emptyCount = globalColumnCount - row.count
                    if emptyCount > 0 {
                        ForEach(0..<emptyCount, id: \.self) { _ in
                            Color.clear
                                .frame(width: 140)
                        }
                    }
                }
            }
        }
        .padding(32)
    }
    
    private var tableRows: [[SeatingTable]] {
        stride(from: 0, to: tables.count, by: globalColumnCount).map { start in
            Array(tables[start..<min(start + globalColumnCount, tables.count)])
        }
    }
}

// MARK: - 設定シート（会場設定ハブ）
private struct SettingsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var globalTableColumnCount: Int
    @Binding var sessionUnlockedColumns: Bool
    @ObservedObject var adManager: RewardedAdManager
    // premiumManager removed: PRO gating removed
    
    @State private var tempSelection: Int = 2
    @State private var pendingColumnCount: Int? = nil
    @State private var showingAdNotReadyAlertLocal: Bool = false
    @State private var showingRequireUnlockAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("テーブルの並び列数")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Picker(selection: $tempSelection, label: Text("")) {
                        ForEach(1...10, id: \.self) { i in
                            Text("\(i)列").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    
                    Text("※1〜2列は無料で即時利用できます。3列以上は動画広告視聴による解放が必要です。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        applySelection()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                tempSelection = globalTableColumnCount
            }
            .alert("広告の準備ができていません。", isPresented: $showingAdNotReadyAlertLocal) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
            }
            .alert("3列以上はアンロックが必要です", isPresented: $showingRequireUnlockAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("動画を視聴して解放") {
                    // Try to show ad
                    if adManager.isAdReady {
                        // ユーザーが選択した列数を一時保持
                        pendingColumnCount = tempSelection
                        adManager.showAd {
                            // 動画視聴完了後に保持した列数を反映
                            if let pendingCount = pendingColumnCount {
                                sessionUnlockedColumns = true
                                globalTableColumnCount = pendingCount
                                pendingColumnCount = nil
                                dismiss()
                            }
                        }
                    } else {
                        adManager.loadAd()
                        showingAdNotReadyAlertLocal = true
                    }
                }
            } message: {
                Text("3列以上のレイアウトを利用するには動画広告の視聴が必要です。")
            }
        }
    }
    
    private func applySelection() {
        // 1〜2列は即時適用
        if tempSelection <= 2 {
            globalTableColumnCount = tempSelection
            dismiss()
            return
        }
        
        // 3列以上は解放済みであれば適用
        if sessionUnlockedColumns {
            globalTableColumnCount = tempSelection
            dismiss()
            return
        }
        
        // それ以外は解放アラートを表示して広告再生を促す
        showingRequireUnlockAlert = true
    }
}


// MARK: - 個別のテーブル表示用コンポーネント (メイン画面用・変更なし)
struct SeatingTableView: View {
    let table: SeatingTable
    @ObservedObject var presenter: SeatingChartPresenter
    let onEditTarget: () -> Void
    
    // バッジ描画のヘルパー（個別に切り出すことで型推論負荷を下げつつ、確実に表示させる）
    @ViewBuilder
    private func badgeTop() -> some View {
        if table.layoutDirection == .top {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(y: -6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeBottom() -> some View {
        if table.layoutDirection == .bottom {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(y: 6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeLeft() -> some View {
        if table.layoutDirection == .left {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.left")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(x: -6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeRight() -> some View {
        if table.layoutDirection == .right {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(.white))
                .offset(x: 6)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if table.layoutDirection != .none && !table.layoutText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(table.layoutText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // 座席グリッドは LazyVGrid だと親の高さ計算が不安定になるため、即時レイアウトの Grid を使う
            let minSeatWidth: CGFloat = 72
            let desiredWidth = CGFloat(table.columnCount) * minSeatWidth
            let columnCount = max(1, table.columnCount)
            let allSeats: [SeatingMember?] = {
                var seats: [SeatingMember?] = table.assignedMembers.map { Optional($0) }
                let emptyCount = max(0, table.capacity - table.assignedMembers.count)
                seats.append(contentsOf: Array(repeating: nil, count: emptyCount))
                return seats
            }()
            let rowCount = max(1, Int(ceil(Double(allSeats.count) / Double(columnCount))))
            
            Group {
                if columnCount <= 4 {
                    seatGrid(allSeats: allSeats, columnCount: columnCount, rowCount: rowCount)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        seatGrid(allSeats: allSeats, columnCount: columnCount, rowCount: rowCount)
                            .frame(minWidth: desiredWidth)
                    }
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: table.assignedMembers)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            onEditTarget()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        // レイアウト方向バッジ（枠の辺の中央に表示）
        .overlay(badgeTop(), alignment: .top)
        .overlay(badgeBottom(), alignment: .bottom)
        .overlay(badgeLeft(), alignment: .leading)
        .overlay(badgeRight(), alignment: .trailing)
    }
    
    @ViewBuilder
    private func seatGrid(allSeats: [SeatingMember?], columnCount: Int, rowCount: Int) -> some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 12) {
            ForEach(0..<rowCount, id: \.self) { row in
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { col in
                        let index = row * columnCount + col
                        if index < allSeats.count {
                            if let member = allSeats[index] {
                                Button {
                                    presenter.toggleLock(tableId: table.id, memberId: member.id)
                                } label: {
                                    SeatView(member: member)
                                }
                                .buttonStyle(.plain)
                                .id(member.id.uuidString)
                            } else {
                                EmptySeatCell(idString: "\(table.id.uuidString)-empty-\(index)")
                            }
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
    }
}

// 1つ1つの「座席」
struct SeatView: View {
    let member: SeatingMember?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: member?.isLocked == true ? "person.circle.fill" : "person.circle")
                    .font(.system(size: 24))
                    .foregroundColor(member == nil ? .gray.opacity(0.3) : (member!.isLocked ? .red : .blue))
                
                if member?.isLocked == true {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
            }
            
            Text(member?.name ?? "空席")
                .font(.system(size: 11, weight: member?.isLocked == true ? .bold : .medium))
                .foregroundColor(member == nil ? .gray.opacity(0.5) : (member!.isLocked ? .red : .primary))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            member?.isLocked == true
            ? Color.red.opacity(0.1)
            : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(6)
    }
}

// 小さなヘルパー視点: 空席セルをラップして複雑な式を外に出す
private struct EmptySeatCell: View {
    let idString: String
    
    var body: some View {
        SeatView(member: nil)
            .id(idString)
    }
}

// MARK: - 編集用画面
struct TableEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var presenter: SeatingChartPresenter
    
    @State private var name: String
    @State private var capacity: Int
    @State private var columnCount: Int
    @State private var layoutDirection: LayoutDirection
    @State private var layoutText: String
    @State private var applyToAllTables: Bool = false
    private let maxInputLength: Int = 20
    let tableId: UUID
    
    init(table: SeatingTable, presenter: SeatingChartPresenter) {
        self.presenter = presenter
        self.tableId = table.id
        _name = State(initialValue: table.name)
        _capacity = State(initialValue: table.capacity)
        _columnCount = State(initialValue: table.columnCount)
        _layoutDirection = State(initialValue: table.layoutDirection)
        _layoutText = State(initialValue: table.layoutText)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本設定") {
                    TextField("テーブル名（例: テーブルA・最大20文字）", text: $name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > maxInputLength {
                                name = String(newValue.prefix(maxInputLength))
                            }
                        }
                    Stepper("定員: \(capacity)人", value: $capacity, in: 1...10)
                        .onChange(of: capacity) { _, newValue in
                            // 定員が減った場合、列数も自動的に調整
                            if columnCount > newValue {
                                columnCount = newValue
                            }
                        }
                    Stepper("横の列数: \(columnCount)列", value: $columnCount, in: 1...capacity)
                    
                    Toggle("すべてのテーブルに適用", isOn: $applyToAllTables)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("会場レイアウト（向き）") {
                    // 十字の方向ボタン
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Button(action: { withAnimation { layoutDirection = .top } }) {
                                Image(systemName: "arrow.up")
                                    .font(.title2)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(layoutDirection == .top ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundColor(layoutDirection == .top ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            Button(action: { withAnimation { layoutDirection = .left } }) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(layoutDirection == .left ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundColor(layoutDirection == .left ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: { withAnimation { layoutDirection = .right } }) {
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(layoutDirection == .right ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundColor(layoutDirection == .right ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            Spacer()
                            Button(action: { withAnimation { layoutDirection = .bottom } }) {
                                Image(systemName: "arrow.down")
                                    .font(.title2)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(layoutDirection == .bottom ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundColor(layoutDirection == .bottom ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            Button(action: { withAnimation { layoutDirection = .none; layoutText = "" } }) {
                                Text("指定なし")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    
                    // テキストのプリセットと自由入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ラベル（例：窓際／ステージ側）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Menu {
                                Button("窓際") { layoutText = "窓際" }
                                Button("ステージ側") { layoutText = "ステージ側" }
                                Button("入り口側") { layoutText = "入り口側" }
                                Button("通路側") { layoutText = "通路側" }
                            } label: {
                                Label("よく使う語", systemImage: "tag")
                                    .padding(8)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(6)
                            }
                            
                            TextField("例: 窓際（20文字まで）", text: $layoutText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: layoutText) { _, newValue in
                                    if newValue.count > maxInputLength {
                                        layoutText = String(newValue.prefix(maxInputLength))
                                    }
                                }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        presenter.deleteTable(id: tableId)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("このテーブルを削除")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("テーブル編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if applyToAllTables {
                            presenter.updateAllTables(
                                editingTableId: tableId,
                                newName: name,
                                newCapacity: capacity,
                                newColumnCount: columnCount,
                                newLayoutDirection: layoutDirection,
                                newLayoutText: layoutText
                            )
                        } else {
                            presenter.updateTable(
                                id: tableId,
                                newName: name,
                                newCapacity: capacity,
                                newColumnCount: columnCount,
                                newLayoutDirection: layoutDirection,
                                newLayoutText: layoutText
                            )
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 新設: 画像出力専用のテーブル表示コンポーネント
// ※ LazyVGridは画面外を描画しないため見切れる。こちらはVStack/HStackを使い全て即時描画する。
struct SnapshotSeatingTableView: View {
    let table: SeatingTable
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                
                if table.layoutDirection != .none && !table.layoutText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(table.layoutText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // 全ての席（空席含む）の配列を作成
            let assignedOptional: [SeatingMember?] = table.assignedMembers.map { Optional($0) }
            let paddingCount = max(0, table.capacity - table.assignedMembers.count)
            let padding: [SeatingMember?] = Array(repeating: nil, count: paddingCount)
            let allSeats = assignedOptional + padding
            let colCount = max(1, table.columnCount)
            let rowCount = (allSeats.count + colCount - 1) / colCount
            
            VStack(spacing: 12) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 12) {
                        ForEach(0..<colCount, id: \.self) { colIndex in
                            let index = rowIndex * colCount + colIndex
                            if index < allSeats.count {
                                SeatView(member: allSeats[index])
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        .overlay(badgeTopSmall(), alignment: .top)
        .overlay(badgeBottomSmall(), alignment: .bottom)
        .overlay(badgeLeftSmall(), alignment: .leading)
        .overlay(badgeRightSmall(), alignment: .trailing)
    }
    
    @ViewBuilder
    private func badgeTopSmall() -> some View {
        if table.layoutDirection == .top {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.up")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(y: -4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeBottomSmall() -> some View {
        if table.layoutDirection == .bottom {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.down")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(y: 4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeLeftSmall() -> some View {
        if table.layoutDirection == .left {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.left")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(x: -4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func badgeRightSmall() -> some View {
        if table.layoutDirection == .right {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(Image(systemName: "arrow.right")
                    .font(.system(size: 7))
                    .foregroundColor(.white))
                .offset(x: 4)
                .zIndex(1)
        } else {
            EmptyView()
        }
    }
}
