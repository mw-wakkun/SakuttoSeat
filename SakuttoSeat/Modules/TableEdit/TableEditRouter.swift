//
//  TableEditRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子モジュールの組み立て）
//

import SwiftUI

final class TableEditRouter {

    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(draft: TableEditDraft, output: (any TableEditModuleOutput)?) -> AnyView {
        let interactor = TableEditInteractor(draft: draft)
        let presenter = TableEditPresenter(interactor: interactor, output: output)
        return AnyView(TableEditView(presenter: presenter))
    }
}
