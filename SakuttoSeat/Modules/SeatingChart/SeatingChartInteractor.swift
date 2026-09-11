//
//  SeatingChartInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//  refactor_templateListView.md Phase 3（保存・読込適用は Snapshot / ID。@Model は Gateway 内）
//

import Foundation

nonisolated final class SeatingChartInteractor: SeatingChartInteractorProtocol {
    private let attendees: [Attendee]
    /// 子モジュール（VenueSettings）にも引き継ぐセッション解放状態
    let featureUnlock: FeatureUnlockState
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var templateGateway: SeatingTemplateGatewayBase
    private var tables: [SeatingTable] = []
    private var venueSettings: VenueSettings

    init(
        attendees: [Attendee] = [],
        venueSettings: VenueSettings = .default,
        featureUnlock: FeatureUnlockState? = nil,
        templateGateway: SeatingTemplateGatewayBase = SeatingTemplateGatewayBase()
    ) {
        self.attendees = attendees
        self.venueSettings = venueSettings
        self.featureUnlock = featureUnlock ?? FeatureUnlockState()
        self.templateGateway = templateGateway
        _ = buildInitialTables()
    }

    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase) {
        templateGateway = gateway
    }

    /// Router が子モジュール組み立て時に同じインスタンスを渡すための供給口。
    /// Presenter の公開面には出さない。
    func currentTemplateGateway() -> SeatingTemplateGatewayBase {
        templateGateway
    }

    func currentTables() -> [SeatingTable] {
        tables
    }

    func currentVenueSettings() -> VenueSettings {
        venueSettings
    }

    var isSessionUnlocked: Bool {
        featureUnlock.isSessionUnlocked
    }

    // MARK: - 座席割り当て

    @discardableResult
    func buildInitialTables() -> [SeatingTable] {
        let attendeeCount = attendees.count
        let baseCapacity = venueSettings.defaultCapacity
        let numberOfTables = max(1, Int(ceil(Double(attendeeCount) / Double(baseCapacity))))

        var initialTables: [SeatingTable] = []
        for index in 0..<numberOfTables {
            initialTables.append(
                SeatingTable(
                    name: Self.tableName(at: index),
                    capacity: baseCapacity,
                    columnCount: min(venueSettings.defaultColumnCount, baseCapacity),
                    layoutDirection: .none,
                    layoutText: "",
                    assignedMembers: []
                )
            )
        }
        tables = assign(attendees: attendees, to: initialTables, shuffle: false)
        return tables
    }

    @discardableResult
    func shuffleSeats() -> [SeatingTable] {
        tables = assign(attendees: attendees, to: tables, shuffle: true)
        return tables
    }

    @discardableResult
    func reassignInRegistrationOrder() -> [SeatingTable] {
        tables = assign(attendees: attendees, to: tables, shuffle: false)
        return tables
    }

    @discardableResult
    func toggleLock(tableID: TableID, memberID: MemberID) -> [SeatingTable] {
        guard let tableIndex = tables.firstIndex(where: { $0.id == tableID }),
              let memberIndex = tables[tableIndex].assignedMembers.firstIndex(where: { $0.id == memberID }) else {
            return tables
        }
        tables[tableIndex].assignedMembers[memberIndex].isLocked.toggle()
        return tables
    }

    /// 割り当てアルゴリズムの純関数インターフェース（状態は更新しない）。
    /// 既存の回帰テストと `SeatSlot` の id 安定性検証がこの入口を使う。
    func shuffleAndAssign(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable] {
        assign(attendees: attendees, to: tables, shuffle: true)
    }

    func assignInRegistrationOrder(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable] {
        assign(attendees: attendees, to: tables, shuffle: false)
    }

    // MARK: - テーブル構成

    @discardableResult
    func addTable() -> [SeatingTable] {
        addTable(capacity: nil, columnCount: nil)
    }

    @discardableResult
    func addTable(capacity: Int?, columnCount: Int?) -> [SeatingTable] {
        let resolvedCapacity = max(1, capacity ?? venueSettings.defaultCapacity)
        let resolvedColumnCount = min(max(1, columnCount ?? venueSettings.defaultColumnCount), resolvedCapacity)
        tables.append(
            SeatingTable(
                name: nextTableName(),
                capacity: resolvedCapacity,
                columnCount: resolvedColumnCount
            )
        )
        return tables
    }

    @discardableResult
    func deleteTable(id: TableID) -> [SeatingTable] {
        tables.removeAll(where: { $0.id == id })
        return reassignInRegistrationOrder()
    }

    @discardableResult
    func applyTableUpdate(_ request: TableUpdateRequest) -> [SeatingTable] {
        request.applyToAll ? updateAllTables(request) : updateTable(request)
    }

    @discardableResult
    func updateTable(_ request: TableUpdateRequest) -> [SeatingTable] {
        guard let index = tables.firstIndex(where: { $0.id == request.tableID }) else {
            return tables
        }

        let capacityChanged = tables[index].capacity != request.capacity
        tables[index].name = request.name
        tables[index].capacity = request.capacity
        tables[index].columnCount = min(request.columnCount, request.capacity)
        tables[index].layoutDirection = request.layoutDirection
        tables[index].layoutText = request.layoutText
        if tables[index].assignedMembers.count > request.capacity {
            tables[index].assignedMembers = Array(tables[index].assignedMembers.prefix(request.capacity))
        }

        if capacityChanged {
            ensureSufficientTables(targetCapacity: request.capacity, targetColumnCount: request.columnCount)
            _ = reassignInRegistrationOrder()
            removeEmptyTables()
        }
        return tables
    }

    @discardableResult
    func updateAllTables(_ request: TableUpdateRequest) -> [SeatingTable] {
        let capacity = max(1, request.capacity)
        let columnCount = min(max(1, request.columnCount), capacity)

        venueSettings.defaultCapacity = capacity
        venueSettings.defaultColumnCount = columnCount

        if let index = tables.firstIndex(where: { $0.id == request.tableID }) {
            tables[index].name = request.name
            tables[index].layoutDirection = request.layoutDirection
            tables[index].layoutText = request.layoutText
        }
        unifyTableLayout(capacity: capacity, columnCount: columnCount)

        ensureSufficientTables(targetCapacity: capacity, targetColumnCount: columnCount)
        unifyTableLayout(capacity: capacity, columnCount: columnCount)
        _ = reassignInRegistrationOrder()
        removeEmptyTables()
        return tables
    }

    /// 子モジュール（TableEdit）へ渡す編集初期値。Entity はここから外に出さない。
    func tableEditDraft(for id: TableID) -> TableEditDraft? {
        guard let table = tables.first(where: { $0.id == id }) else { return nil }
        return TableEditDraft(
            tableID: table.id,
            name: table.name,
            capacity: table.capacity,
            columnCount: table.columnCount,
            layoutDirection: table.layoutDirection,
            layoutText: table.layoutText,
            applyToAllTables: false
        )
    }

    // MARK: - 会場設定と解放

    func columnCountChangeRequirement(for count: Int) -> UnlockRequirement {
        if count <= FeatureLimit.freeColumnCount {
            return .none
        }
        return featureUnlock.isSessionUnlocked ? .none : .rewardedAd
    }

    @discardableResult
    func applyColumnCount(_ count: Int) throws -> VenueSettings {
        switch columnCountChangeRequirement(for: count) {
        case .none:
            venueSettings.globalColumnCount = count
            return venueSettings
        case .rewardedAd:
            throw VenueSettingsError.unlockRequired(requested: count)
        }
    }

    func grantSessionUnlock() {
        featureUnlock.grantSessionUnlock()
    }

    // MARK: - テンプレート

    func templateSaveAvailability() -> TemplateSaveAvailability {
        let currentCount = (try? templateGateway.fetchCount()) ?? 0
        if currentCount < FeatureLimit.freeTemplateCount {
            return .available
        }
        return .limitReached(currentCount: currentCount, limit: FeatureLimit.freeTemplateCount)
    }

    func saveCurrentLayoutAsTemplate(named name: String) throws {
        switch templateSaveAvailability() {
        case .limitReached(let currentCount, let limit):
            throw TemplateSaveError.limitReached(currentCount: currentCount, limit: limit)
        case .available:
            break
        }

        guard !tables.isEmpty else {
            throw TemplateSaveError.emptyLayout
        }
        guard let snapshot = makeLayoutTemplate(named: name) else {
            throw TemplateSaveError.invalidName
        }

        do {
            try templateGateway.insert(
                name: snapshot.name,
                tables: snapshot.tables,
                globalColumnCount: snapshot.globalColumnCount
            )
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func makeLayoutTemplate(named name: String) -> LayoutTemplateSnapshot? {
        guard !tables.isEmpty else { return nil }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let templateTables = tables.map { table in
            TableTemplate(
                name: table.name,
                capacity: table.capacity,
                columnCount: table.columnCount,
                layoutDirection: table.layoutDirection,
                layoutText: table.layoutText
            )
        }
        return LayoutTemplateSnapshot(
            name: name,
            tables: templateTables,
            globalColumnCount: venueSettings.globalColumnCount
        )
    }

    @discardableResult
    func applyTemplate(_ snapshot: LayoutTemplateSnapshot) -> [SeatingTable] {
        let restoredTables = snapshot.tables.enumerated().map { index, tableTemplate in
            SeatingTable(
                id: index < tables.count ? tables[index].id : UUID(),
                name: tableTemplate.name,
                capacity: tableTemplate.capacity,
                columnCount: tableTemplate.columnCount,
                layoutDirection: tableTemplate.layoutDirection,
                layoutText: tableTemplate.layoutText,
                assignedMembers: []
            )
        }

        if let firstTable = restoredTables.first,
           restoredTables.allSatisfy({ $0.capacity == firstTable.capacity && $0.columnCount == firstTable.columnCount }) {
            venueSettings.defaultCapacity = firstTable.capacity
            venueSettings.defaultColumnCount = firstTable.columnCount
        }

        venueSettings.globalColumnCount = snapshot.globalColumnCount
        tables = assign(attendees: attendees, to: restoredTables, shuffle: false)
        return tables
    }

    @discardableResult
    func loadAndApplyTemplate(id: SeatingTemplateID) throws -> [SeatingTable] {
        let snapshot: LayoutTemplateSnapshot?
        do {
            snapshot = try templateGateway.fetch(id: id)
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }

        guard let snapshot else {
            throw TemplateSaveError.notFound
        }

        return applyTemplate(snapshot)
    }

    // MARK: - テーブル名

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

    // MARK: - Private

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
            let resolvedCapacity = max(1, targetCapacity ?? tables.last?.capacity ?? venueSettings.defaultCapacity)
            let resolvedColumnCount = min(
                targetColumnCount ?? tables.last?.columnCount ?? venueSettings.defaultColumnCount,
                resolvedCapacity
            )
            let tablesToAdd = max(1, Int(ceil(Double(neededCapacity) / Double(resolvedCapacity))))

            for _ in 0..<tablesToAdd {
                _ = addTable(capacity: resolvedCapacity, columnCount: resolvedColumnCount)
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

    private func assign(attendees: [Attendee], to tables: [SeatingTable], shuffle: Bool) -> [SeatingTable] {
        var updatedTables = tables
        var lockedMembers: [UUID: (member: SeatingMember, tableIndex: Int, seatIndex: Int)] = [:]
        var currentlyAssignedIDs: Set<UUID> = []

        for (tableIndex, table) in tables.enumerated() {
            for (seatIndex, member) in table.assignedMembers.enumerated() {
                if member.isLocked {
                    lockedMembers[member.id] = (member, tableIndex, seatIndex)
                    currentlyAssignedIDs.insert(member.id)
                }
            }
        }

        let movableAttendees = attendees.filter { !currentlyAssignedIDs.contains($0.id) }
        let orderedAttendees = shuffle ? movableAttendees.shuffled() : movableAttendees
        var nameIndex = 0

        for tableIndex in 0..<updatedTables.count {
            var newMembersForTable: [SeatingMember] = []
            let capacity = updatedTables[tableIndex].capacity

            for seatIndex in 0..<capacity {
                if let locked = lockedMembers.values.first(where: { $0.tableIndex == tableIndex && $0.seatIndex == seatIndex }) {
                    newMembersForTable.append(locked.member)
                } else if nameIndex < orderedAttendees.count {
                    let attendee = orderedAttendees[nameIndex]
                    newMembersForTable.append(SeatingMember(id: attendee.id, name: attendee.name, isLocked: false))
                    nameIndex += 1
                }
            }
            updatedTables[tableIndex].assignedMembers = newMembersForTable
        }
        return updatedTables
    }
}
