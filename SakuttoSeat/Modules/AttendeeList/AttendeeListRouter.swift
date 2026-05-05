//
//  AttendeeListRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI

class AttendeeListRouter {
    static func assembleModule() -> some View {
        let interactor = AttendeeListInteractor()
        let router = AttendeeListRouter()
        let presenter = AttendeeListPresenter(interactor: interactor, router: router)
        return AttendeeListView(presenter: presenter)
    }
}
