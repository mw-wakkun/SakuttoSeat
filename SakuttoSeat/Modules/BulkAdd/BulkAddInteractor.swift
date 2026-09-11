//
//  BulkAddInteractor.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5
//  入力検証のみ。パース（改行・カンマ分割）は親 AttendeeListInteractor に残す。
//

import Foundation

nonisolated final class BulkAddInteractor: BulkAddInteractorProtocol {
    private(set) var text: String = ""

    var delimiterHint: String { BulkAddCopy.delimiterHint }

    var canConfirm: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func updateText(_ text: String) -> String {
        self.text = text
        return self.text
    }
}
