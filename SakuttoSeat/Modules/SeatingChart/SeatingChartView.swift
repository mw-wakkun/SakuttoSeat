//
//  SeatingChartView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI

struct SeatingChartView: View {
    @StateObject var presenter: SeatingChartPresenter
    @State private var editingTable: SeatingTable?
    
    // 画面を左右に2分割するグリッド定義
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
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
                        .frame(minHeight: 120) // 他のテーブルと高さを合わせる
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            // 下部の確定ボタン
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
    let onEditTarget: () -> Void // 編集画面を開くためのクロージャを追加
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(table.name)
                .font(.caption)
                .bold()
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 12) {
                // 【修正】インデックスではなく、実在するメンバーを直接展開する
                ForEach(table.assignedMembers) { member in
                    SeatView(member: member)
                        .id(member.id.uuidString) // IDを確実に固定
                        .onTapGesture {
                            // 確実にタップされたmember本人のIDが渡る
                            presenter.toggleLock(tableId: table.id, memberId: member.id)
                        }
                }
                
                // 空席分がある場合は、その数だけ空のシートを描画（タップ不可）
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
                .fill(Color.white)
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
        .background(member?.isLocked == true ? Color.red.opacity(0.05) : Color.gray.opacity(0.03))
        .cornerRadius(6)
    }
}

// MARK: - 編集用画面
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
        .presentationDetents([.medium])
    }
}

// MARK: - Preview用
#Preview {
    let previewAttendees = [
        Attendee(name: "田中"),
        Attendee(name: "佐藤")
    ]
    return SeatingChartRouter.assembleModule(attendees: previewAttendees)
}
