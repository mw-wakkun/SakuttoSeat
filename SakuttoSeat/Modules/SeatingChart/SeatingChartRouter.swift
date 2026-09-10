//
//  SeatingChartRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（遷移・提示・子モジュール組み立て）
//

import SwiftUI
import UIKit

final class SeatingChartRouter: SeatingChartRouterProtocol {
    /// 子モジュールの組み立てに必要な親 Presenter（Phase 5 で子 Presenter に置き換える）
    weak var presenter: SeatingChartPresenter?

    /// モジュールの組み立て（Builder 相当）
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SeatingChartInteractor(
            attendees: attendees,
            featureUnlock: SessionFeatureUnlock.shared
        )
        let router = SeatingChartRouter()
        let presenter = SeatingChartPresenter(interactor: interactor, router: router)
        return AnyView(SeatingChartView(presenter: presenter))
    }

    // MARK: - 提示（UIKit を必要とするため Router の責務）

    @MainActor
    func presentShareSheet(text: String) {
        ShareSheetPresenter.present(items: [text])
    }

    @MainActor
    func presentShareSheet(image: UIImage) {
        ShareSheetPresenter.present(items: [image])
    }

    @MainActor
    func presentShareSheetWhenReady(text: String) async {
        await ShareSheetPresenter.presentWhenReady(items: [text])
    }

    @MainActor
    func presentShareSheetWhenReady(image: UIImage) async {
        await ShareSheetPresenter.presentWhenReady(items: [image])
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await RewardedAdPresenter.present()
    }

    /// 成功したら true。レンダリング不可なら false を返し、Presenter がアラートを出す。
    @MainActor
    @discardableResult
    func exportAndShareSeatingChart(viewData: SeatingChartViewData) async -> Bool {
        guard let image = ImageExportRenderer.renderSeatingChart(viewData: viewData) else {
            return false
        }
        await presentShareSheetWhenReady(image: image)
        return true
    }

    // MARK: - 子モジュールの組み立て（Phase 5 で独立モジュールへ）
    //
    // TableEdit / VenueSettings はまだ親 Presenter を直接参照する暫定実装のため、
    // `output` は受け取るだけで結線しない。Phase 5 で子 Presenter へ注入する。

    @MainActor
    func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView {
        guard let presenter else { return AnyView(EmptyView()) }
        return AnyView(TableEditView(tableID: tableID, presenter: presenter))
    }

    @MainActor
    func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView {
        guard let presenter else { return AnyView(EmptyView()) }
        return AnyView(
            SettingsSheetView(
                globalTableColumnCount: Binding(
                    get: { presenter.globalColumnCount },
                    set: { presenter.globalColumnCount = $0 }
                ),
                sessionUnlockedColumns: Binding(
                    get: { presenter.sessionUnlockedColumns },
                    set: { presenter.sessionUnlockedColumns = $0 }
                ),
                adManager: RewardedAdManager.shared
            )
            .presentationDetents([.medium])
        )
    }

    @MainActor
    func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView {
        AnyView(
            SeatingTemplateListView { template in
                output.templateListDidSelect(template: template)
            }
            .presentationDetents([.medium, .large])
        )
    }
}
