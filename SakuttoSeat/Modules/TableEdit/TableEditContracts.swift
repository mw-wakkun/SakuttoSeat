//
//  TableEditContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子 VIPER モジュール化）
//

import Foundation

// MARK: - 編集中の値

/// 編集対象の初期値。親（SeatingChartInteractor）が Entity から組み立てて渡す。
///
/// `nonisolated`: 既定の MainActor 隔離だと明示 init を
/// `nonisolated` な Interactor から呼べないため。
nonisolated struct TableEditDraft: Equatable {
    let tableID: TableID
    var name: String
    var capacity: Int
    var columnCount: Int
    var layoutDirection: LayoutDirection
    var layoutText: String
    var applyToAllTables: Bool

    init(
        tableID: TableID,
        name: String,
        capacity: Int,
        columnCount: Int,
        layoutDirection: LayoutDirection = .none,
        layoutText: String = "",
        applyToAllTables: Bool = false
    ) {
        self.tableID = tableID
        self.name = name
        self.capacity = capacity
        self.columnCount = columnCount
        self.layoutDirection = layoutDirection
        self.layoutText = layoutText
        self.applyToAllTables = applyToAllTables
    }
}

enum TableEditRoute: Identifiable, Equatable {
    case seatShortage

    var id: String {
        switch self {
        case .seatShortage:
            return "seatShortage"
        }
    }
}

/// View が消費する表示専用モデル
struct TableEditViewData: Equatable {
    let name: String
    let capacity: Int
    let capacityRange: ClosedRange<Int>
    let columnCount: Int
    let columnCountRange: ClosedRange<Int>
    let layoutDirection: LayoutDirection
    let layoutText: String
    let applyToAllTables: Bool
    let maxInputLength: Int
    let layoutTextPresets: [String]
}

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol TableEditPresenterProtocol: AnyObject {
    var viewData: TableEditViewData { get }
    var route: TableEditRoute? { get set }

    func didChangeName(_ name: String)
    func didChangeCapacity(_ capacity: Int)
    func didChangeColumnCount(_ columnCount: Int)
    func didSelectLayoutDirection(_ direction: LayoutDirection)
    func didChangeLayoutText(_ text: String)
    func didToggleApplyToAllTables(_ isOn: Bool)
    func didTapSave()
    func didConfirmApplyDespiteSeatShortage()
    func dismissRoute()
    func didTapDelete()
    func didTapCancel()
}

// MARK: - Presenter -> Interactor

nonisolated protocol TableEditInteractorProtocol: AnyObject {
    var draft: TableEditDraft { get }
    var capacityRange: ClosedRange<Int> { get }
    var columnCountRange: ClosedRange<Int> { get }
    var maxInputLength: Int { get }
    var layoutTextPresets: [String] { get }

    @discardableResult func updateName(_ name: String) -> TableEditDraft
    @discardableResult func updateCapacity(_ capacity: Int) -> TableEditDraft
    @discardableResult func updateColumnCount(_ columnCount: Int) -> TableEditDraft
    @discardableResult func updateLayoutDirection(_ direction: LayoutDirection) -> TableEditDraft
    @discardableResult func updateLayoutText(_ text: String) -> TableEditDraft
    @discardableResult func updateApplyToAllTables(_ isOn: Bool) -> TableEditDraft

    func makeUpdateRequest() -> TableUpdateRequest
    func needsSeatShortageConfirmation() -> Bool
}

// MARK: - Presenter -> 親モジュール

protocol TableEditModuleOutput: AnyObject {
    func tableEditDidCommit(_ request: TableUpdateRequest)
    func tableEditDidRequestDelete(tableID: TableID)
    func tableEditDidCancel()
}
