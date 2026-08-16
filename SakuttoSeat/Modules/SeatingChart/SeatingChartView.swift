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
    @State private var editingTable: SeatingTable?
    @State private var isShowingSaveAlert = false
    @State private var templateName = ""
    @State private var isShowingTemplateList = false
    @State private var showTemplateLimitAlert = false
    // MARK: - アンロック・広告管理
    @StateObject private var stateManager = AppStateManager.shared
    @StateObject private var adManager = RewardedAdManager.shared
    
    @State private var showingUnlockSheet = false
    @State private var shouldShowAdOnDismiss = false
    
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
                    ForEach(presenter.tables) { table in
                        SeatingTableView(table: table, presenter: presenter, onEditTarget: {
                            editingTable = table
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
                        presentShareSheet(with: shareText)
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
        .sheet(item: $editingTable) { table in
            TableEditView(table: table, presenter: presenter)
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
    
    // シェアシートを呼び出す
    private func presentShareSheet(with text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true, completion: nil)
    }
}

// MARK: - 個別のテーブル表示用コンポーネント
struct SeatingTableView: View {
    let table: SeatingTable
    @ObservedObject var presenter: SeatingChartPresenter
    let onEditTarget: () -> Void
    
    // テーブルの設定列数に応じた動的グリッド
    private var tableColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, table.columnCount))
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                Text(table.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                
                if table.orientation != .none {
                    Text(table.orientation.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            LazyVGrid(columns: tableColumns, spacing: 12) {
                ForEach(table.assignedMembers) { member in
                    SeatView(member: member)
                        .id(member.id.uuidString)
                        .onTapGesture {
                            presenter.toggleLock(tableId: table.id, memberId: member.id)
                        }
                }
                
                if table.assignedMembers.count < table.capacity {
                    ForEach(0..<(table.capacity - table.assignedMembers.count), id: \.self) { emptyIndex in
                        SeatView(member: nil)
                            .id("\(table.id.uuidString)-empty-\(emptyIndex)")
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

// MARK: - 編集用画面
struct TableEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var presenter: SeatingChartPresenter
    
    @State private var name: String
    @State private var capacity: Int
    @State private var columnCount: Int
    @State private var orientation: TableOrientation
    let tableId: UUID
    
    init(table: SeatingTable, presenter: SeatingChartPresenter) {
        self.presenter = presenter
        self.tableId = table.id
        _name = State(initialValue: table.name)
        _capacity = State(initialValue: table.capacity)
        _columnCount = State(initialValue: table.columnCount)
        _orientation = State(initialValue: table.orientation)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本設定") {
                    TextField("テーブル名", text: $name)
                    Stepper("定員: \(capacity)人", value: $capacity, in: 2...10)
                    Stepper("横の列数: \(columnCount)列", value: $columnCount, in: 1...4)
                }
                
                Section("会場レイアウト（向き）") {
                    Picker("向き", selection: $orientation) {
                        ForEach(TableOrientation.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
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
                            newOrientation: orientation
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
