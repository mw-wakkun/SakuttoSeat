//
//  AttendeeListRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI

class AttendeeListRouter {
    
    /// モジュールの初期組み立て（アプリ起動時などに使用）
    @MainActor
    static func assembleModule() -> some View {
        let interactor = AttendeeListInteractor()
        let router = AttendeeListRouter()
        let presenter = AttendeeListPresenter(
            interactor: interactor,
            router: router
        )
        return AttendeeListView(presenter: presenter)
    }
    
    // MARK: - Navigation Methods
    
    /// 座席表画面（SeatingChart）を組み立てて返す
    @MainActor
    func makeSeatingChartView(attendees: [Attendee]) -> AnyView {
        // mapで名前だけにせず、attendeesをそのまま渡す
        return SeatingChartRouter.assembleModule(attendees: attendees)
    }
    
    /// 番号札画面（SimpleShuffle）を組み立てて返す
    @MainActor
    func makeSimpleShuffleView(attendees: [String]) -> AnyView {
        let presenter = SimpleShufflePresenter(attendees: attendees)
        let view = SimpleShuffleView(presenter: presenter)
        return AnyView(view)
    }
}
