//
//  TableEditInteractor.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5
//  もとは TableEditView が @State と .onChange で持っていた入力規則
//  （20 文字制限・定員と列数の連動）をここへ移送する。
//

import Foundation

nonisolated final class TableEditInteractor: TableEditInteractorProtocol {
    let capacityRange: ClosedRange<Int> = 1...10
    let maxInputLength: Int = 20
    let layoutTextPresets: [String] = ["窓際", "ステージ側", "入り口側", "通路側"]

    private(set) var draft: TableEditDraft
    private let attendeeCount: Int
    private let tableCapacities: [TableID: Int]

    var columnCountRange: ClosedRange<Int> { 1...max(1, draft.capacity) }

    init(
        draft: TableEditDraft,
        attendeeCount: Int = 0,
        tableCapacities: [TableID: Int] = [:]
    ) {
        self.draft = draft
        self.attendeeCount = max(0, attendeeCount)
        self.tableCapacities = tableCapacities
        self.draft.name = Self.clamped(draft.name, maxLength: maxInputLength)
        self.draft.capacity = Self.clamped(draft.capacity, to: capacityRange)
        self.draft.columnCount = Self.clamped(draft.columnCount, to: 1...max(1, self.draft.capacity))
        self.draft.layoutText = Self.clamped(draft.layoutText, maxLength: maxInputLength)
    }

    @discardableResult
    func updateName(_ name: String) -> TableEditDraft {
        draft.name = Self.clamped(name, maxLength: maxInputLength)
        return draft
    }

    /// 定員が減った場合は列数も追従させる（定員を超える列数は作れない）
    @discardableResult
    func updateCapacity(_ capacity: Int) -> TableEditDraft {
        draft.capacity = Self.clamped(capacity, to: capacityRange)
        if draft.columnCount > draft.capacity {
            draft.columnCount = draft.capacity
        }
        return draft
    }

    @discardableResult
    func updateColumnCount(_ columnCount: Int) -> TableEditDraft {
        draft.columnCount = Self.clamped(columnCount, to: columnCountRange)
        return draft
    }

    /// 「指定なし」を選んだらラベルも消す（旧 View の挙動を踏襲）
    @discardableResult
    func updateLayoutDirection(_ direction: LayoutDirection) -> TableEditDraft {
        draft.layoutDirection = direction
        if direction == .none {
            draft.layoutText = ""
        }
        return draft
    }

    @discardableResult
    func updateLayoutText(_ text: String) -> TableEditDraft {
        draft.layoutText = Self.clamped(text, maxLength: maxInputLength)
        return draft
    }

    @discardableResult
    func updateApplyToAllTables(_ isOn: Bool) -> TableEditDraft {
        draft.applyToAllTables = isOn
        return draft
    }

    func makeUpdateRequest() -> TableUpdateRequest {
        TableUpdateRequest(
            tableID: draft.tableID,
            name: draft.name,
            capacity: draft.capacity,
            columnCount: draft.columnCount,
            layoutDirection: draft.layoutDirection,
            layoutText: draft.layoutText,
            applyToAll: draft.applyToAllTables
        )
    }

    /// 40卓まで足しても全員を載せられないときだけ警告する。
    /// 一括適用でない場合は、他卓の定員を残したうえで足りるかを見る。
    func needsSeatShortageConfirmation() -> Bool {
        maximumSeatsAfterApply() < attendeeCount
    }

    // MARK: - Private

    private func maximumSeatsAfterApply() -> Int {
        let capacity = max(1, draft.capacity)
        if draft.applyToAllTables {
            return capacity * FeatureLimit.maxTableCount
        }
        var otherCapacity = 0
        var otherCount = 0
        for (id, existing) in tableCapacities where id != draft.tableID {
            otherCapacity += existing
            otherCount += 1
        }
        let remainingSlots = max(1, FeatureLimit.maxTableCount - otherCount)
        return otherCapacity + capacity * remainingSlots
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clamped(_ text: String, maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
    }
}
