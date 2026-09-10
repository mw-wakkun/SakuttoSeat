//
//  SeatingChartRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import SwiftUI
import UIKit

final class SeatingChartRouter: SeatingChartRouterProtocol {
    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SeatingChartInteractor()
        let router = SeatingChartRouter()
        let presenter = SeatingChartPresenter(interactor: interactor, router: router, attendees: attendees)
        let view = SeatingChartView(presenter: presenter)
        return AnyView(view)
    }

    // MARK: - SeatingChartRouterProtocol（Phase 4 で実体化。Phase 2 は契約固定用スタブ）

    func presentShareSheet(text: String) {
        // Phase 4: UIActivityViewController をここに集約する
    }

    func presentShareSheet(image: UIImage) {
        // Phase 4: UIActivityViewController をここに集約する
    }

    func presentRewardedAd() async throws {
        // Phase 4: RewardedAdManager の async/await 化
    }

    func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView {
        // Phase 4/5: 子モジュール組み立て
        AnyView(EmptyView())
    }

    func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView {
        AnyView(EmptyView())
    }

    func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView {
        AnyView(EmptyView())
    }
}
