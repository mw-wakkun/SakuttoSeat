//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import Combine

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
    
    // 指定したテーブルの情報を更新するメソッドを追加
    func updateTable(id: UUID, newName: String, newCapacity: Int) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            tables[index].name = newName
            tables[index].capacity = newCapacity
            // 設定が変わったので、一度メンバーの割り当てをリセット（または再配置）
            shuffle()
        }
    }
    
    func updateTable(id: UUID, newName: String, newCapacity: Int, newOrientation: TableOrientation) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            tables[index].name = newName
            tables[index].capacity = newCapacity
            tables[index].orientation = newOrientation
            // 向きの変更だけならシャッフルし直す必要はないので、そのままにする
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
