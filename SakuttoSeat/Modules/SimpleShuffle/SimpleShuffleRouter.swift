//
//  SimpleShuffleRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 4（Router の箱。本体の VIPER 化は Phase 5）
//

import SwiftUI

final class SimpleShuffleRouter {

    /// モジュールの組み立て（Builder 相当）。
    /// Phase 5 で ID を維持したまま ViewData 化する。ここでは名前配列へ写像する。
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let presenter = SimpleShufflePresenter(attendees: attendees.map(\.name))
        return AnyView(SimpleShuffleView(presenter: presenter))
    }
}
