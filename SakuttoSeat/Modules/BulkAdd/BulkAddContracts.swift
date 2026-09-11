//
//  BulkAddContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（一括追加の子 VIPER モジュール）
//

import Foundation

// MARK: - 表示専用モデル

enum BulkAddCopy {
    /// 親 Interactor の分割文字（改行 / 半角カンマ / 読点）と一致させる
    static var delimiterHint: String {
        String(localized: "改行またはカンマ（, または 、）区切りで参加者名を入力・ペーストしてください。")
    }
}

struct BulkAddViewData: Equatable {
    let text: String
    let canConfirm: Bool
    let delimiterHint: String

    static let empty = BulkAddViewData(
        text: "",
        canConfirm: false,
        delimiterHint: BulkAddCopy.delimiterHint
    )
}

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol BulkAddPresenterProtocol: AnyObject {
    var viewData: BulkAddViewData { get }

    func didChangeText(_ text: String)
    func didTapConfirm()
    func didTapCancel()
}

// MARK: - Presenter -> Interactor

nonisolated protocol BulkAddInteractorProtocol: AnyObject {
    var text: String { get }
    var canConfirm: Bool { get }
    var delimiterHint: String { get }

    @discardableResult func updateText(_ text: String) -> String
}

// MARK: - Presenter -> 親モジュール

protocol BulkAddModuleOutput: AnyObject {
    func bulkAddDidConfirm(text: String)
    func bulkAddDidCancel()
}
