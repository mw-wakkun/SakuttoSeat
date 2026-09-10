//
//  TableEditView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）
//  Phase 5 でこのフォルダに Presenter / Interactor / Router を追加し、
//  独立した子 VIPER モジュールとして完成させる。
//

import SwiftUI

/// テーブル編集画面
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
    let tableId: TableID

    /// Phase 2: 親 View は Entity を持たず `TableID` だけ渡す。
    /// 初期値は Presenter から引き、見つからない場合は安全な既定値で開く。
    init(tableID: TableID, presenter: SeatingChartPresenter) {
        self.presenter = presenter
        self.tableId = tableID
        let table = presenter.table(for: tableID)
        _name = State(initialValue: table?.name ?? "")
        _capacity = State(initialValue: table?.capacity ?? 4)
        _columnCount = State(initialValue: table?.columnCount ?? 2)
        _layoutDirection = State(initialValue: table?.layoutDirection ?? .none)
        _layoutText = State(initialValue: table?.layoutText ?? "")
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
                        withAnimation(.easeInOut(duration: 0.25)) {
                            presenter.didRequestDeleteTable(id: tableId)
                        }
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
                        let request = TableUpdateRequest(
                            tableID: tableId,
                            name: name,
                            capacity: capacity,
                            columnCount: columnCount,
                            layoutDirection: layoutDirection,
                            layoutText: layoutText,
                            applyToAll: applyToAllTables
                        )
                        withAnimation(.easeInOut(duration: 0.25)) {
                            presenter.didCommitTableEdit(request)
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
