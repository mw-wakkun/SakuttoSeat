//
//  SeatingChartRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI

protocol SeatingChartRouterProtocol {
    // 将来、この画面からさらに別の画面へ遷移する場合はここに定義します
}

class SeatingChartRouter: SeatingChartRouterProtocol {
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SeatingChartInteractor()
        let router = SeatingChartRouter()
        let presenter = SeatingChartPresenter(interactor: interactor, router: router, attendees: attendees)
        let view = SeatingChartView(presenter: presenter)
        return AnyView(view)
    }
}
