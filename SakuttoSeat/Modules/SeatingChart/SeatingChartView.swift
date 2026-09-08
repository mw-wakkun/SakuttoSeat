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
    @StateObject private var stateManager = AppStateManager.shared
    @StateObject private var adManager = RewardedAdManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    
    @State private var showingUnlockSheet = false
    @State private var shouldShowAdOnDismiss = false
    @State private var showingShareOptions = false
    @State private var pendingShareSelection: ShareSelectionKind?
    @State private var showingImageShareAdAlert = false
    @State private var showingAdNotReadyAlert = false
    
    // 画面全体（テーブル同士）を左右に2分割するグリッド定義
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
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
        VStack(spacing: 0) {
            // メインの座席表コンテンツ
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(presenter.tables.indices, id: \.self) { idx in
                        let table = presenter.tables[idx]
                        SeatingTableView(table: table, presenter: presenter, onEditTarget: {
                            editingTableIndex = idx
                        })
                    }
                    
                    // テーブル追加ボタン
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
                }
                .padding()
            }
            
            // 下部エリア：アクションボタン ＆ 広告バナー
            VStack(spacing: 8) {
                // 共通化したアクションボタン
                ActionButtonsView(
                    // 1番目：お気に入り（テンプレート読込）
                    button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                        isShowingTemplateList = true
                    }),
                    // 2番目：保存
                    button2: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                        templateName = ""
                        // 動画で解放済み、または無料枠（3個未満）なら保存ダイアログを表示
                        if stateManager.hasUnlockedUnlimitedGroups || presenter.canSaveTemplate(context: modelContext) {
                            isShowingSaveAlert = true
                        } else {
                            // 3個以上かつ未解放の場合はアンロックシートを表示
                            showingUnlockSheet = true
                        }
                    }, isDisabled: presenter.tables.isEmpty),
                    // 3番目：共有
                    button3: .init(title: "共有", icon: "square.and.arrow.up", color: .blue, action: {
                        showingShareOptions = true
                    }, isDisabled: presenter.tables.isEmpty),
                    // 4番目：シャッフル
                    button4: .init(title: "シャッフル", icon: "shuffle", color: .purple, action: {
                        presenter.shuffle()
                    })
                )
                .padding(.horizontal, 16)
                
                // 下部：広告バナーエリア
                AdBannerView()
                    .frame(width: 320, height: 50)
                    .padding(.bottom, 4)
            }
            .padding(.top, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .navigationTitle("座席表")
        .navigationBarTitleDisplayMode(.inline)
        // テンプレート保存用アラート
        .alert("レイアウトを保存", isPresented: $isShowingSaveAlert) {
            TextField("テンプレート名 (例: デフォルト設定)", text: $templateName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                presenter.saveLayoutAsTemplate(templateName: templateName, context: modelContext)
            }
        } message: {
            Text("現在のテーブル構成をテンプレートとして保存します。")
        }
        .sheet(isPresented: Binding(get: { editingTableIndex != nil }, set: { newVal in if !newVal { editingTableIndex = nil } })) {
            if let idx = editingTableIndex, presenter.tables.indices.contains(idx) {
                TableEditView(table: presenter.tables[idx], presenter: presenter)
            }
        }
        .onAppear {
            if presenter.tables.allSatisfy({ $0.assignedMembers.isEmpty }) {
                presenter.shuffle()
            }
        }
        // テンプレート一覧シートの呼び出し
        .sheet(isPresented: $isShowingTemplateList) {
            SeatingTemplateListView { selectedTemplate in
                presenter.applyTemplate(selectedTemplate)
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
                        // 動画視聴完了でフラグを更新し、保存アラートを表示
                        stateManager.hasUnlockedUnlimitedGroups = true
                        isShowingSaveAlert = true // 既存の保存ダイアログフラグ
                    }
                }
            }
        }) {
            UnlockSheetView {
                shouldShowAdOnDismiss = true
            }
        }
    }
    
    private func handleImageShareTapped() {
        if premiumManager.isPro {
            exportAndShareSeatingChartImage()
        } else {
            showingImageShareAdAlert = true
        }
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
        let exportWidth = UIScreen.main.bounds.width
        
        // ★修正点: 専用のSnapshotViewを呼び出し、presenterは不要に
        let exportView = SeatingChartSnapshotView(tables: presenter.tables)
            .frame(width: exportWidth)
            .background(Color(.systemBackground))
        
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: nil)
        
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
    // ★修正点: Snapshot専用なのでpresenterの監視を削除
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(tableRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row) { table in
                        // ★修正点: 画像出力専用のLazyを使わないコンポーネントに変更
                        SnapshotSeatingTableView(table: table)
                    }
                    if row.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
    }
    
    private var tableRows: [[SeatingTable]] {
        stride(from: 0, to: tables.count, by: 2).map { start in
            Array(tables[start..<min(start + 2, tables.count)])
        }
    }
}

// MARK: - 個別のテーブル表示用コンポーネント (メイン画面用・変更なし)
struct SeatingTableView: View {
    let table: SeatingTable
    @ObservedObject var presenter: SeatingChartPresenter
    let onEditTarget: () -> Void
    
    // テーブルの設定列数に応じた動的グリッド
    private var tableColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, table.columnCount))
    }

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
        let tableIdString = table.id.uuidString

        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
            
            LazyVGrid(columns: tableColumns, spacing: 12) {
                ForEach(table.assignedMembers) { member in
                    Button {
                        presenter.toggleLock(tableId: table.id, memberId: member.id)
                    } label: {
                        SeatView(member: member)
                    }
                    .buttonStyle(.plain)
                    .id(member.id.uuidString)
                }
                
                let emptyCount = max(0, table.capacity - table.assignedMembers.count)
                if emptyCount > 0 {
                    ForEach(0..<emptyCount, id: \.self) { emptyIndex in
                        let idString = "\(tableIdString)-empty-\(emptyIndex)"
                        EmptySeatCell(idString: idString)
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
                    Stepper("定員: \(capacity)人", value: $capacity, in: 2...10)
                    Stepper("横の列数: \(columnCount)列", value: $columnCount, in: 1...4)
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
                        presenter.updateTable(
                            id: tableId,
                            newName: name,
                            newCapacity: capacity,
                            newColumnCount: columnCount,
                            newLayoutDirection: layoutDirection,
                            newLayoutText: layoutText
                        )
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
                                    .frame(maxWidth: .infinity)
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
