//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import Combine
import SwiftData

class SeatingChartPresenter: ObservableObject {
    @Published var tables: [SeatingTable] = []
    private let attendees: [Attendee]
    private let interactor: SeatingChartInteractorProtocol
    private let router: SeatingChartRouterProtocol
    
    init(interactor: SeatingChartInteractorProtocol, router: SeatingChartRouterProtocol, attendees: [Attendee]) {
        self.interactor = interactor
        self.router = router
        self.attendees = attendees
        setupInitialTables()
    }
    
    private func setupInitialTables() {
        let attendeeCount = attendees.count
        let baseCapacity = 4 // 飲み会で一般的な4名席を基準にする
        
        // 必要なテーブル数を算出（例：5人なら2テーブル）
        let numberOfTables = max(1, Int(ceil(Double(attendeeCount) / Double(baseCapacity))))
        
        var initialTables: [SeatingTable] = []
        
        for i in 0..<numberOfTables {
            let letter = String(UnicodeScalar(UInt8(65 + i)))
            let newTable = SeatingTable(
                name: "テーブル\(letter)",
                capacity: baseCapacity,
                orientation: .none,
                assignedMembers: []
            )
            initialTables.append(newTable)
        }
        
        self.tables = initialTables
    }
    
    // テーブルを追加する処理
    func addTable() {
        let newTableName = "テーブル\(Character(UnicodeScalar(65 + tables.count)!))"
        tables.append(SeatingTable(name: newTableName, capacity: 4))
    }
    
    // シャッフル実行の処理
    func shuffle() {
        // スプリングアニメーションを適用して、席が「ピョンッ」と入れ替わる演出にします
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            tables = interactor.shuffleAndAssign(attendees: attendees, to: tables)
        }
    }
    
    // 指定したテーブルの情報を更新するメソッド
    func updateTable(id: UUID, newName: String, newCapacity: Int, newColumnCount: Int, newOrientation: TableOrientation) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            // アニメーション付きで変更を確実にViewへ通知する
            withAnimation(.easeInOut(duration: 0.25)) {
                var updatedTable = tables[index]
                updatedTable.name = newName
                updatedTable.capacity = newCapacity
                updatedTable.columnCount = newColumnCount // ★ 列数の更新を追加
                updatedTable.orientation = newOrientation
                
                // 配列の要素自体を新しい構造体で置き換えることで、@Published の変更通知を確実に飛ばします
                tables[index] = updatedTable
            }
        }
    }
    
    func updateTable(id: UUID, newName: String, newCapacity: Int, newOrientation: TableOrientation) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            // アニメーション付きで変更を確実にViewへ通知する
            withAnimation(.easeInOut(duration: 0.25)) {
                var updatedTable = tables[index]
                updatedTable.name = newName
                updatedTable.capacity = newCapacity
                updatedTable.orientation = newOrientation
                
                // 配列の要素自体を新しい構造体で置き換えることで、@Published の変更通知を確実に飛ばします
                tables[index] = updatedTable
            }
        }
    }
    
    // 指定したテーブルの指定した席をロック/アンロックする
    func toggleLock(tableId: UUID, memberId: UUID) {
        if let tIndex = tables.firstIndex(where: { $0.id == tableId }),
           let mIndex = tables[tIndex].assignedMembers.firstIndex(where: { $0.id == memberId }) {
            tables[tIndex].assignedMembers[mIndex].isLocked.toggle()
        }
    }
    
    func deleteTable(id: UUID) {
        tables.removeAll(where: { $0.id == id })
        // 削除後に再配置しないと、消えたテーブルにいた人が消えてしまうため
        // 自動でシャッフルし直すのが親切です
        shuffle()
    }
}

extension SeatingChartPresenter {
    // 現在のテーブル構成をテンプレートとして保存する
    func saveLayoutAsTemplate(templateName: String, context: ModelContext) {
        guard !tables.isEmpty else { return }
        guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 現在のSeatingTableから、レイアウト情報だけを抽出
        let templateTables = tables.map { table in
            TableTemplate(
                name: table.name,
                capacity: table.capacity,
                columnCount: table.columnCount,
                orientation: table.orientation
            )
        }
        
        let newTemplate = SeatingLayoutTemplate(name: templateName, tables: templateTables)
        context.insert(newTemplate)
        
        do {
            try context.save()
        } catch {
            print("レイアウトテンプレートの保存に失敗しました: \(error)")
        }
    }
    
    // 選択したテンプレートを現在の座席表に適用する
    func applyTemplate(_ template: SeatingLayoutTemplate) {
        // テンプレートのテーブル情報(TableTemplate)から、表示用の(SeatingTable)を生成
        let restoredTables = template.tables.map { t in
            SeatingTable(
                name: t.name,
                capacity: t.capacity,
                columnCount: t.columnCount,
                orientation: t.orientation,
                assignedMembers: []
            )
        }
        
        // 新しいテーブル構成に現在の参加者を割り当てる
        let newlyAssignedTables = interactor.shuffleAndAssign(attendees: attendees, to: restoredTables)
        
        // 参加者が割り当てられた完成形のテーブルで、画面をアニメーション更新
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            self.tables = newlyAssignedTables
        }
    }
    
    func canSaveTemplate(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>()
        // データベースに保存されているテンプレートの数を取得
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count < 3
    }
}
