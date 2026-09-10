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
    /// モジュールの組み立て（Builder 相当）
    ///
    /// Phase 4 で遷移・提示メソッドを `SeatingChartRouterProtocol` に追加し、
    /// Router を実体化する。
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SeatingChartInteractor()
        let router = SeatingChartRouter()
        let presenter = SeatingChartPresenter(interactor: interactor, router: router, attendees: attendees)
        let view = SeatingChartView(presenter: presenter)
        return AnyView(view)
    }
}
