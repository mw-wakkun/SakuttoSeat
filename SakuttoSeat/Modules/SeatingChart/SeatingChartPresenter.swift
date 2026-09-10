//
//  SeatingChartPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import Combine
import SwiftData

@MainActor
class SeatingChartPresenter: ObservableObject {
    @Published var tables: [SeatingTable] = []
    // View側のScrollViewReaderに最上部スクロールを通知するためのトリガー
    @Published var scrollToTopTrigger: Int = 0
    private let attendees: [Attendee]
    private let interactor: SeatingChartInteractorProtocol
    private let router: SeatingChartRouterProtocol
    // 新しくテーブルを作るときの既定値。「すべてのテーブルに適用」で更新され、
    // 以降に自動追加・手動追加されるテーブルもこの設定で揃える
    private var defaultCapacity: Int = 4
    private var defaultColumnCount: Int = 2
    
    init(interactor: SeatingChartInteractorProtocol, router: SeatingChartRouterProtocol, attendees: [Attendee]) {
        self.interactor = interactor
        self.router = router
        self.attendees = attendees
        setupInitialTables()
    }
    
    private func setupInitialTables() {
        let attendeeCount = attendees.count
        let baseCapacity = defaultCapacity // 飲み会で一般的な4名席を基準にする
        
        // 必要なテーブル数を算出（例：5人なら2テーブル）
        let numberOfTables = max(1, Int(ceil(Double(attendeeCount) / Double(baseCapacity))))
        
        var initialTables: [SeatingTable] = []
        
        for i in 0..<numberOfTables {
            let newTable = SeatingTable(
                name: Self.tableName(at: i),
                capacity: baseCapacity,
                columnCount: min(defaultColumnCount, baseCapacity),
                layoutDirection: .none,
                layoutText: "",
                assignedMembers: []
            )
            initialTables.append(newTable)
        }
        
        // 初期表示は登録順のまま割り当て
        self.tables = interactor.assignInRegistrationOrder(attendees: attendees, to: initialTables)
    }
    
    // テーブルを追加する処理
    // 定員・列数の指定がない場合は「すべてのテーブルに適用」で設定された値を引き継ぐ
    func addTable(capacity: Int? = nil, columnCount: Int? = nil) {
        let resolvedCapacity = max(1, capacity ?? defaultCapacity)
        let resolvedColumnCount = min(max(1, columnCount ?? defaultColumnCount), resolvedCapacity)
        tables.append(SeatingTable(
            name: nextTableName(),
            capacity: resolvedCapacity,
            columnCount: resolvedColumnCount
        ))
    }

    // 未使用のテーブル名（A, B, ... Z, AA, AB ...）を先頭から探して払い出す
    private func nextTableName() -> String {
        let usedNames = Set(tables.map(\.name))
        var index = 0
        while true {
            let candidate = Self.tableName(at: index)
            if !usedNames.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }

    // 0 -> テーブルA, 25 -> テーブルZ, 26 -> テーブルAA（1人席で27個以上になっても破綻しない）
    static func tableName(at index: Int) -> String {
        var remainder = index
        var letters = ""
        repeat {
            let scalarValue = UInt8(65 + remainder % 26)
            letters = String(UnicodeScalar(scalarValue)) + letters
            remainder = remainder / 26 - 1
        } while remainder >= 0
        return "テーブル\(letters)"
    }
    
    // 登録順のまま全テーブルにメンバーを再割り当て（シャッフルはしない）
    func assignInOrder() {
        withAnimation(.easeInOut(duration: 0.25)) {
            tables = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)
        }
    }
    
    // シャッフル実行の処理（ボタンタップ時のみ呼び出される想定）
    func shuffle() {
        // スプリングアニメーションを適用して、席が「ピョンッ」と入れ替わる演出にします
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            tables = interactor.shuffleAndAssign(attendees: attendees, to: tables)
        }
    }
    
    // 指定したテーブルの情報を更新するメソッド
    func updateTable(id: UUID, newName: String, newCapacity: Int, newColumnCount: Int, newLayoutDirection: LayoutDirection, newLayoutText: String) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            // 定員が変更されたかどうかをチェック
            let oldCapacity = tables[index].capacity
            let capacityChanged = oldCapacity != newCapacity

            // アニメーション付きで変更を確実にViewへ通知する
            withAnimation(.easeInOut(duration: 0.25)) {
                var updatedTable = tables[index]
                updatedTable.name = newName
                updatedTable.capacity = newCapacity
                updatedTable.columnCount = min(newColumnCount, newCapacity)
                updatedTable.layoutDirection = newLayoutDirection
                updatedTable.layoutText = newLayoutText
                // 定員からあふれる席は手放し、再割り当てで別テーブルへ移す
                if updatedTable.assignedMembers.count > newCapacity {
                    updatedTable.assignedMembers = Array(updatedTable.assignedMembers.prefix(newCapacity))
                }

                // 配列の要素自体を新しい構造体で置き換えることで、@Published の変更通知を確実に飛ばします
                tables[index] = updatedTable
            }

            // 定員が変更された場合、新しい定員に合わせて座席を再配置
            if capacityChanged {
                // 定員変更時に必要なテーブル数をチェックし、不足している場合は追加
                ensureSufficientTables(targetCapacity: newCapacity, targetColumnCount: newColumnCount)
                assignInOrder()
                // 再割り当て後に不要な空テーブルを削除
                removeEmptyTables()
            }

            // 保存完了後、表示を最上部へリセット
            scrollToTopTrigger += 1
        }
    }

    // すべてのテーブルの定員と列数を一括更新するメソッド
    // 名前と会場レイアウトはテーブルごとの情報のため、編集中のテーブルにだけ反映する
    func updateAllTables(
        editingTableId: UUID,
        newName: String,
        newCapacity: Int,
        newColumnCount: Int,
        newLayoutDirection: LayoutDirection,
        newLayoutText: String
    ) {
        let capacity = max(1, newCapacity)
        let columnCount = min(max(1, newColumnCount), capacity)

        // 以降に追加されるテーブルも同じ設定で生成されるように既定値を更新
        defaultCapacity = capacity
        defaultColumnCount = columnCount

        withAnimation(.easeInOut(duration: 0.25)) {
            if let index = tables.firstIndex(where: { $0.id == editingTableId }) {
                tables[index].name = newName
                tables[index].layoutDirection = newLayoutDirection
                tables[index].layoutText = newLayoutText
            }
            unifyTableLayout(capacity: capacity, columnCount: columnCount)
        }

        // 定員変更後に必要なテーブル数をチェックし、不足している場合は追加
        ensureSufficientTables(targetCapacity: capacity, targetColumnCount: columnCount)
        // 追加されたテーブルも含めて、定員と列数を完全に統一する
        unifyTableLayout(capacity: capacity, columnCount: columnCount)
        assignInOrder()
        // 再割り当て後に不要な空テーブルを削除
        removeEmptyTables()

        // 一括適用完了後、表示を最上部へリセット
        scrollToTopTrigger += 1
    }

    // 全テーブルの定員・列数を指定値に揃える
    private func unifyTableLayout(capacity: Int, columnCount: Int) {
        for index in tables.indices {
            tables[index].capacity = capacity
            tables[index].columnCount = columnCount
            // 新しい定員からあふれる席は一旦手放し、再割り当ての対象に戻す
            // （ロック席のまま残すと、その参加者がどのテーブルにも並ばず消えてしまう）
            if tables[index].assignedMembers.count > capacity {
                tables[index].assignedMembers = Array(tables[index].assignedMembers.prefix(capacity))
            }
        }
    }

    // 全参加者を収容するために十分なテーブル数があることを確認
    private func ensureSufficientTables(targetCapacity: Int? = nil, targetColumnCount: Int? = nil) {
        let attendeeCount = attendees.count
        let totalCapacity = tables.reduce(0) { $0 + $1.capacity }

        // 総座席数が参加者数より少ない場合、不足分を補う
        if totalCapacity < attendeeCount {
            let neededCapacity = attendeeCount - totalCapacity
            // 引数で指定された定員を優先、なければ最後のテーブルの定員、最終的に既定値
            let resolvedCapacity = max(1, targetCapacity ?? tables.last?.capacity ?? defaultCapacity)
            let resolvedColumnCount = min(targetColumnCount ?? tables.last?.columnCount ?? defaultColumnCount, resolvedCapacity)
            let tablesToAdd = max(1, Int(ceil(Double(neededCapacity) / Double(resolvedCapacity))))

            for _ in 0..<tablesToAdd {
                addTable(capacity: resolvedCapacity, columnCount: resolvedColumnCount)
            }
        }
    }

    // 不要な空テーブルを削除
    private func removeEmptyTables() {
        // 末尾の空テーブルを削除（最低1つのテーブルは残す）
        while tables.count > 1 {
            if let lastTable = tables.last, lastTable.assignedMembers.isEmpty {
                tables.removeLast()
            } else {
                break
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
        // 登録順で再割り当てを行う
        assignInOrder()
    }
}

extension SeatingChartPresenter {
    // 現在のテーブル構成をテンプレートとして保存する
    func saveLayoutAsTemplate(templateName: String, globalColumnCount: Int, context: ModelContext) {
        guard !tables.isEmpty else { return }
        guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 現在のSeatingTableから、レイアウト情報だけを抽出
        let templateTables = tables.map { table in
            TableTemplate(
                name: table.name,
                capacity: table.capacity,
                columnCount: table.columnCount,
                layoutDirection: table.layoutDirection,
                layoutText: table.layoutText
            )
        }
        
        let newTemplate = SeatingLayoutTemplate(name: templateName, tables: templateTables, globalColumnCount: globalColumnCount)
        context.insert(newTemplate)
        
        do {
            try context.save()
        } catch {
            print("レイアウトテンプレートの保存に失敗しました: \(error)")
        }
    }
    
    // 選択したテンプレートを現在の座席表に適用する
    func applyTemplate(_ template: SeatingLayoutTemplate) -> Int {
        // テンプレートのテーブル情報(TableTemplate)から、表示用の(SeatingTable)を生成
        let restoredTables = template.tables.map { t in
            SeatingTable(
                name: t.name,
                capacity: t.capacity,
                columnCount: t.columnCount,
                layoutDirection: t.layoutDirection,
                layoutText: t.layoutText,
                assignedMembers: []
            )
        }

        // 全テーブルが同じ定員のテンプレートなら、以降に追加するテーブルもその設定に合わせる
        if let firstTable = restoredTables.first,
           restoredTables.allSatisfy({ $0.capacity == firstTable.capacity && $0.columnCount == firstTable.columnCount }) {
            defaultCapacity = firstTable.capacity
            defaultColumnCount = firstTable.columnCount
        }

        // 新しいテーブル構成に現在の参加者を登録順で割り当てる
        let newlyAssignedTables = interactor.assignInRegistrationOrder(attendees: attendees, to: restoredTables)

        // 参加者が割り当てられた完成形のテーブルで、画面をアニメーション更新
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            self.tables = newlyAssignedTables
        }

        // テンプレート適用完了後、表示を最上部へリセット
        scrollToTopTrigger += 1

        // グローバル列数を返す
        return template.globalColumnCount
    }
    
    func canSaveTemplate(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>()
        // データベースに保存されているテンプレートの数を取得
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count < 3
    }
}
