//
//  SeatingChartContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（Router 実体化・Gateway 化）
//  Phase 5（子モジュール切り出し・Share モジュール化）
//

import SwiftUI

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
    /// 共有フローは Share モジュールが担う（View はこの Presenter に `.shareFlow` を取り付ける）
    var share: SharePresenter { get }

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
    func didTapSettings()
    func dismissRoute()

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
    /// 子モジュール（TableEdit）へ渡す編集初期値
    func tableEditDraft(for id: TableID) -> TableEditDraft?

    func columnCountChangeRequirement(for count: Int) -> UnlockRequirement
    func applyColumnCount(_ count: Int) throws -> VenueSettings
    func grantSessionUnlock()
    var isSessionUnlocked: Bool { get }
    /// 子モジュール（VenueSettings）へ引き継ぐセッション解放状態
    var featureUnlock: FeatureUnlockState { get }

    func templateSaveAvailability() -> TemplateSaveAvailability
    func saveCurrentLayoutAsTemplate(named name: String) throws
    func makeLayoutTemplate(named name: String) -> LayoutTemplateSnapshot?
    func applyTemplate(_ snapshot: LayoutTemplateSnapshot) -> [SeatingTable]
    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase)
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
/// 各メソッドに @MainActor を付与する。
///
/// 共有・広告の提示は Phase 5 で Share モジュール（`ShareRouter`）へ移した。
protocol SeatingChartRouterProtocol: AnyObject {
    @MainActor func makeTableEditModule(draft: TableEditDraft, output: (any TableEditModuleOutput)?) -> AnyView
    @MainActor func makeVenueSettingsModule(
        currentColumnCount: Int,
        featureUnlock: FeatureUnlockState,
        output: (any VenueSettingsModuleOutput)?
    ) -> AnyView
    @MainActor func makeTemplateListModule(output: (any TemplateListModuleOutput)?) -> AnyView
}

// MARK: - 子モジュール Output
//
// TableEdit / VenueSettings の Output は各モジュールの Contracts で定義する。

protocol TemplateListModuleOutput: AnyObject {
    func templateListDidSelect(template: SeatingLayoutTemplate)
    func templateListDidCancel()
}
