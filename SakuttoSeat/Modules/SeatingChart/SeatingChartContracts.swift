//
//  SeatingChartContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（Router 実体化・Gateway 化）
//  Phase 5（子モジュール切り出し・Share モジュール化）
//  refactor_templateListView.md Phase 3（テンプレート子は gatewayHolder。Presenter は Gateway 型を渡さない）
//  refactor_templateListView.md Phase 4（テンプレートシートは Presenter 組み立てと View ラップを分離）
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
    func loadAndApplyTemplate(id: SeatingTemplateID) throws -> [SeatingTable]
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
    /// テンプレート一覧は子 VIPER。assemble とシート View を分ける（シート identity は親 Presenter）。
    /// Presenter は Gateway 型を渡さず、具象 Interactor を gatewayHolder として渡す。
    /// Router はキャッシュしない。`.templateList` 期間中の保持は親 Presenter。
    @MainActor func makeTemplateListPresenter(
        gatewayHolder: SeatingChartInteractor,
        output: (any SeatingTemplateModuleOutput)?
    ) -> SeatingTemplatePresenter
    @MainActor func makeTemplateListSheet(presenter: SeatingTemplatePresenter) -> AnyView
    @MainActor func makeTemplateListModule(
        gatewayHolder: SeatingChartInteractor,
        output: (any SeatingTemplateModuleOutput)?
    ) -> AnyView
}

// MARK: - 子モジュール Output
//
// TableEdit / VenueSettings / SeatingTemplate の Output は各モジュールの Contracts で定義する。
