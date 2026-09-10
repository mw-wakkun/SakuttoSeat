//
//  SeatingChartContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（Router 実体化・Gateway 化）
//

import SwiftUI
import UIKit

// MARK: - View <- Presenter

/// View は Presenter の公開状態のみを読む。Entity は現れない。
///
/// `ObservableObject` は具象 Presenter 側で準拠する。
/// Protocol に載せると MainActor 隔離下の deinit で解放不整合が起きやすいため分離する。
@MainActor
protocol SeatingChartPresenterProtocol: AnyObject {
    var viewData: SeatingChartViewData { get }
    var route: SeatingChartRoute? { get set }
    var canvasEvent: SeatingChartCanvasEvent? { get }

    /// VenueSettings へのファサード（Phase 5 で VenueSettings モジュールへ移管）
    var globalColumnCount: Int { get set }
    /// FeatureUnlockGateway へのファサード（画面を pop してもセッション内は維持）
    var sessionUnlockedColumns: Bool { get set }

    // MARK: View -> Presenter（ユーザー意図）

    func onAppear()
    func didTapAddTable()
    func didTapTable(id: TableID)
    func didTapSeat(tableID: TableID, memberID: MemberID)
    func didTapShuffle()
    func didTapSaveTemplate()
    func didConfirmSaveTemplate(name: String)
    func didTapLoadTemplate()
    func didSelectTemplate(_ template: SeatingLayoutTemplate)
    func didTapShare()
    func didSelectShareKind(_ kind: ShareSelectionKind)
    /// 広告準備状況を View（AdManager）から受け取り、視聴→画像出力まで Router へ委譲する
    func didConfirmImageShareWithAd(isAdReady: Bool)
    func didRequestImageShare()
    func didTapSettings()
    func dismissRoute()

    func makeShareText() -> String

    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase)
}

// MARK: - Presenter -> Interactor

nonisolated protocol SeatingChartInteractorProtocol: AnyObject {
    func currentTables() -> [SeatingTable]
    func currentVenueSettings() -> VenueSettings

    func buildInitialTables() -> [SeatingTable]
    func shuffleSeats() -> [SeatingTable]
    func reassignInRegistrationOrder() -> [SeatingTable]
    func toggleLock(tableID: TableID, memberID: MemberID) -> [SeatingTable]

    func addTable() -> [SeatingTable]
    func deleteTable(id: TableID) -> [SeatingTable]
    func updateTable(_ request: TableUpdateRequest) -> [SeatingTable]
    func updateAllTables(_ request: TableUpdateRequest) -> [SeatingTable]

    func columnCountChangeRequirement(for count: Int) -> UnlockRequirement
    func applyColumnCount(_ count: Int) throws -> VenueSettings
    func grantSessionUnlock()
    var isSessionUnlocked: Bool { get }

    func templateSaveAvailability() -> TemplateSaveAvailability
    func saveCurrentLayoutAsTemplate(named name: String) throws
    func makeLayoutTemplate(named name: String) -> LayoutTemplateSnapshot?
    func applyTemplate(_ snapshot: LayoutTemplateSnapshot) -> [SeatingTable]
    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase)

    func makeShareText() -> String
    func shareImageRequirement() -> UnlockRequirement
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
/// 各メソッドに @MainActor を付与する。
protocol SeatingChartRouterProtocol: AnyObject {
    @MainActor func presentShareSheet(text: String)
    @MainActor func presentShareSheet(image: UIImage)
    @MainActor func presentShareSheetWhenReady(text: String) async
    @MainActor func presentShareSheetWhenReady(image: UIImage) async
    @MainActor func presentRewardedAd() async throws
    @MainActor func exportAndShareSeatingChart(viewData: SeatingChartViewData) async -> Bool
    @MainActor func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView
    @MainActor func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView
    @MainActor func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView
}

// MARK: - 子モジュール Output（Phase 5 で結線）

protocol TableEditModuleOutput: AnyObject {
    func tableEditDidCommit(_ request: TableUpdateRequest)
    func tableEditDidRequestDelete(tableID: TableID)
    func tableEditDidCancel()
}

protocol VenueSettingsModuleOutput: AnyObject {
    func venueSettingsDidApply(columnCount: Int)
    func venueSettingsDidRequestUnlock(for columnCount: Int)
}

protocol TemplateListModuleOutput: AnyObject {
    func templateListDidSelect(template: SeatingLayoutTemplate)
    func templateListDidCancel()
}
