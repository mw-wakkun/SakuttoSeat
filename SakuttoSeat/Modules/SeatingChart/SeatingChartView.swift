//
//  SeatingChartView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI

struct SeatingChartView: View {
    @StateObject var presenter: SeatingChartPresenter
    @State private var isShowingEditAlert = false
    @State private var editingTable: SeatingTable?
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 20) {
                    ForEach(presenter.tables) { table in
                        SeatingTableView(table: table, presenter: presenter)
                            .onTapGesture {
                                editingTable = table
                            }
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
                        .frame(minHeight: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            // シャッフルボタン
            Button(action: {
                presenter.shuffle()
            }) {
                Text("席をサクッと決める")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding()
        }
        .navigationTitle("座席表")
        .sheet(item: $editingTable) { table in
            TableEditView(table: table, presenter: presenter)
        }
        .onAppear {
            // まだ誰も配置されていない（全テーブルの assignedMembers が空）場合のみ実行
            if presenter.tables.allSatisfy({ $0.assignedMembers.isEmpty }) {
                presenter.shuffle()
            }
        }
    }
}

// MARK: - 個別のテーブル表示用コンポーネント
struct SeatingTableView: View {
    let table: SeatingTable
    @ObservedObject var presenter: SeatingChartPresenter
    
    // 2列のグリッドレイアウトを定義（左と右）
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            // 向きラベルの追加
            if table.orientation != .none {
                Text(table.orientation.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
            Text(table.name)
                .font(.caption)
                .bold()
                .foregroundColor(.secondary)
            
            // --- 4人掛けテーブルの視覚的レイアウト ---
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<table.capacity, id: \.self) { index in
                    SeatView(member: index < table.assignedMembers.count ? table.assignedMembers[index] : nil)
                        .onTapGesture {
                            if index < table.assignedMembers.count {
                                presenter.toggleLock(tableId: table.id, memberId: table.assignedMembers[index].id)
                            }
                        }
                }
            }
        }
        .padding(15)
        .background(
            // 中央の「机」を表現する背景
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// 1つ1つの「座席」を表現する小さなパーツ
struct SeatView: View {
    let member: SeatingMember? // StringからSeatingMemberに変更
    
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(member?.isLocked == true ? Color.red.opacity(0.05) : Color.gray.opacity(0.03))
        .cornerRadius(6)
        .animation(.easeInOut, value: member?.id)
    }
}

// MARK: - 編集用画面 (別ファイルにしてもOK)
struct TableEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var presenter: SeatingChartPresenter
    
    @State private var name: String
    @State private var capacity: Int
    @State private var orientation: TableOrientation
    let tableId: UUID
    
    init(table: SeatingTable, presenter: SeatingChartPresenter) {
        self.presenter = presenter
        self.tableId = table.id
        _name = State(initialValue: table.name)
        _capacity = State(initialValue: table.capacity)
        _orientation = State(initialValue: table.orientation)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本設定") {
                    TextField("テーブル名", text: $name)
                    Stepper("定員: \(capacity)人", value: $capacity, in: 2...10)
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        presenter.updateTable(id: tableId, newName: name, newCapacity: capacity, newOrientation: orientation)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium]) // 半分の高さで表示
    }
}

// MARK: - Preview用
#Preview {
    SeatingChartRouter.assembleModule(attendees: ["田中", "佐藤", "鈴木", "高橋", "伊藤", "渡辺"])
}
