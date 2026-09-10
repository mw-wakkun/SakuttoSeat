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
final class SeatingChartPresenter: ObservableObject, SeatingChartPresenterProtocol {
    /// tables / globalColumnCount の変更通知に乗せて再計算する（二重 @Published を避ける）
    var viewData: SeatingChartViewData {
        SeatingChartViewDataBuilder.build(
            tables: tables,
            globalColumnCount: globalColumnCount
        )
    }

    @Published var route: SeatingChartRoute?
    @Published var scrollToTopTrigger: Int = 0
    @Published var globalColumnCount: Int = 2
    @Published var sessionUnlockedColumns: Bool = false
    @Published var pendingShareSelection: ShareSelectionKind?
    @Published var shouldShowAdOnDismiss: Bool = false

    /// ドメイン状態。Phase 3 で Interactor へ移送する。View は参照しない。
    @Published private(set) var tables: [SeatingTable] = []

    private let attendees: [Attendee]
    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: SeatingChartInteractor
    // 新しくテーブルを作るときの既定値。「すべてのテーブルに適用」で更新され、
    // 以降に自動追加・手動追加されるテーブルもこの設定で揃える
    private var defaultCapacity: Int = 4
    private var defaultColumnCount: Int = 2

    init(interactor: SeatingChartInteractor, router: SeatingChartRouterProtocol, attendees: [Attendee]) {
        self.interactor = interactor
        self.attendees = attendees
        setupInitialTables()
        // Phase 4 で Router を保持・利用する。現状は契約上受け取るのみ。
        _ = router
    }

    // MARK: - SeatingChartPresenterProtocol（意図メソッド）

    func onAppear() {
        // ViewData は算出プロパティのため、ここでは追加の再構築は不要
    }

    func didTapAddTable() {
        addTable()
    }

    func didTapTable(id: TableID) {
        guard tables.contains(where: { $0.id == id }) else { return }
        route = .tableEdit(id)
    }

    func didTapSeat(tableID: TableID, memberID: MemberID) {
        toggleLock(tableId: tableID, memberId: memberID)
    }

    func didTapShuffle() {
        shuffle()
    }

    func didTapSaveTemplate(canSave: Bool) {
        if canSave {
            route = .saveTemplatePrompt
        } else {
            route = .unlockForSave
        }
    }

    func didConfirmSaveTemplate(name: String, context: ModelContext) {
        saveLayoutAsTemplate(templateName: name, globalColumnCount: globalColumnCount, context: context)
        route = nil
    }

    func didTapLoadTemplate() {
        route = .templateList
    }

    func didSelectTemplate(_ template: SeatingLayoutTemplate) {
        globalColumnCount = applyTemplate(template)
        route = nil
    }

    func didTapShare() {
        route = .shareSelection
    }

    func didSelectShareKind(_ kind: ShareSelectionKind) {
        pendingShareSelection = kind
        route = nil
    }

    func didRequestImageShare() {
        route = .alert(.confirmImageShareWithAd)
    }

    func didConfirmImageShareWithAd(isAdReady: Bool, onReward: @escaping () -> Void) {
        guard isAdReady else {
            route = .alert(.adNotReady)
            return
        }
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Phase 4 で Router.presentRewardedAd に移管する。
            // 現状は View 側の AdManager 呼び出しを onReward 経由で継続する。
            onReward()
        }
    }

    func didTapSettings() {
        route = .venueSettings
    }

    func dismissRoute() {
        route = nil
    }

    func makeShareText() -> String {
        var text = "【サクッと席決め】座席表のシャッフル結果です！\n\n"

        for table in tables {
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

    /// TableEdit など子画面が Entity を必要とする間のブリッジ（Phase 5 で廃止）
    func table(for id: TableID) -> SeatingTable? {
        tables.first(where: { $0.id == id })
    }

    // MARK: - ドメイン操作（Phase 3 で Interactor へ移送）

    private func setupInitialTables() {
        let attendeeCount = attendees.count
        let baseCapacity = defaultCapacity

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

        tables = interactor.assignInRegistrationOrder(attendees: attendees, to: initialTables)
    }

    func addTable(capacity: Int? = nil, columnCount: Int? = nil) {
        let resolvedCapacity = max(1, capacity ?? defaultCapacity)
        let resolvedColumnCount = min(max(1, columnCount ?? defaultColumnCount), resolvedCapacity)
        tables.append(SeatingTable(
            name: nextTableName(),
            capacity: resolvedCapacity,
            columnCount: resolvedColumnCount
        ))
    }

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

    func assignInOrder() {
        withAnimation(.easeInOut(duration: 0.25)) {
            tables = interactor.assignInRegistrationOrder(attendees: attendees, to: tables)
        }
    }

    func shuffle() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            tables = interactor.shuffleAndAssign(attendees: attendees, to: tables)
        }
    }

    func updateTable(id: UUID, newName: String, newCapacity: Int, newColumnCount: Int, newLayoutDirection: LayoutDirection, newLayoutText: String) {
        if let index = tables.firstIndex(where: { $0.id == id }) {
            let oldCapacity = tables[index].capacity
            let capacityChanged = oldCapacity != newCapacity

            withAnimation(.easeInOut(duration: 0.25)) {
                var updatedTable = tables[index]
                updatedTable.name = newName
                updatedTable.capacity = newCapacity
                updatedTable.columnCount = min(newColumnCount, newCapacity)
                updatedTable.layoutDirection = newLayoutDirection
                updatedTable.layoutText = newLayoutText
                if updatedTable.assignedMembers.count > newCapacity {
                    updatedTable.assignedMembers = Array(updatedTable.assignedMembers.prefix(newCapacity))
                }
                tables[index] = updatedTable
            }

            if capacityChanged {
                ensureSufficientTables(targetCapacity: newCapacity, targetColumnCount: newColumnCount)
                assignInOrder()
                removeEmptyTables()
            }

            scrollToTopTrigger += 1
        }
    }

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

        ensureSufficientTables(targetCapacity: capacity, targetColumnCount: columnCount)
        unifyTableLayout(capacity: capacity, columnCount: columnCount)
        assignInOrder()
        removeEmptyTables()

        scrollToTopTrigger += 1
    }

    private func unifyTableLayout(capacity: Int, columnCount: Int) {
        for index in tables.indices {
            tables[index].capacity = capacity
            tables[index].columnCount = columnCount
            if tables[index].assignedMembers.count > capacity {
                tables[index].assignedMembers = Array(tables[index].assignedMembers.prefix(capacity))
            }
        }
    }

    private func ensureSufficientTables(targetCapacity: Int? = nil, targetColumnCount: Int? = nil) {
        let attendeeCount = attendees.count
        let totalCapacity = tables.reduce(0) { $0 + $1.capacity }

        if totalCapacity < attendeeCount {
            let neededCapacity = attendeeCount - totalCapacity
            let resolvedCapacity = max(1, targetCapacity ?? tables.last?.capacity ?? defaultCapacity)
            let resolvedColumnCount = min(targetColumnCount ?? tables.last?.columnCount ?? defaultColumnCount, resolvedCapacity)
            let tablesToAdd = max(1, Int(ceil(Double(neededCapacity) / Double(resolvedCapacity))))

            for _ in 0..<tablesToAdd {
                addTable(capacity: resolvedCapacity, columnCount: resolvedColumnCount)
            }
        }
    }

    private func removeEmptyTables() {
        while tables.count > 1 {
            if let lastTable = tables.last, lastTable.assignedMembers.isEmpty {
                tables.removeLast()
            } else {
                break
            }
        }
    }

    func toggleLock(tableId: UUID, memberId: UUID) {
        if let tIndex = tables.firstIndex(where: { $0.id == tableId }),
           let mIndex = tables[tIndex].assignedMembers.firstIndex(where: { $0.id == memberId }) {
            tables[tIndex].assignedMembers[mIndex].isLocked.toggle()
        }
    }

    func deleteTable(id: UUID) {
        tables.removeAll(where: { $0.id == id })
        assignInOrder()
    }
}

extension SeatingChartPresenter {
    func saveLayoutAsTemplate(templateName: String, globalColumnCount: Int, context: ModelContext) {
        guard !tables.isEmpty else { return }
        guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

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
            route = .alert(.saveFailed(message: error.localizedDescription))
        }
    }

    func applyTemplate(_ template: SeatingLayoutTemplate) -> Int {
        // 同一インデックスのテーブル ID を引き継ぎ、差分アニメーションを維持する（課題 3.3-#8）
        let restoredTables = template.tables.enumerated().map { index, t in
            SeatingTable(
                id: index < tables.count ? tables[index].id : UUID(),
                name: t.name,
                capacity: t.capacity,
                columnCount: t.columnCount,
                layoutDirection: t.layoutDirection,
                layoutText: t.layoutText,
                assignedMembers: []
            )
        }

        if let firstTable = restoredTables.first,
           restoredTables.allSatisfy({ $0.capacity == firstTable.capacity && $0.columnCount == firstTable.columnCount }) {
            defaultCapacity = firstTable.capacity
            defaultColumnCount = firstTable.columnCount
        }

        let newlyAssignedTables = interactor.assignInRegistrationOrder(attendees: attendees, to: restoredTables)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            self.tables = newlyAssignedTables
        }

        scrollToTopTrigger += 1

        return template.globalColumnCount
    }

    func canSaveTemplate(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count < 3
    }
}
