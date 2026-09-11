//
//  BulkAddRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（子モジュールの組み立て）
//

import SwiftUI

final class BulkAddRouter {

    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(output: (any BulkAddModuleOutput)?) -> AnyView {
        let presenter = BulkAddPresenter(interactor: BulkAddInteractor(), output: output)
        return AnyView(BulkAddView(presenter: presenter))
    }
}
