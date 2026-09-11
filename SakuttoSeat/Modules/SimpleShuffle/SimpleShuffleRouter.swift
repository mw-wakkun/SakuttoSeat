//
//  SimpleShuffleRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（番号札モジュールの組み立て）
//

import SwiftUI

final class SimpleShuffleRouter {

    /// モジュールの組み立て（Builder 相当）。親から `[Attendee]` を受け取り ID を維持する。
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SimpleShuffleInteractor(attendees: attendees)
        let presenter = SimpleShufflePresenter(interactor: interactor)
        return AnyView(SimpleShuffleView(presenter: presenter))
    }
}
