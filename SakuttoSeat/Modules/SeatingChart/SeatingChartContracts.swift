//
//  SeatingChartContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 3（Presenter → Interactor へのロジック移送）
//

import SwiftData
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
    /// - Parameter canSave: Phase 4 で Gateway 経由の判定に置き換えるまでの暫定引数
    func didTapSaveTemplate(canSave: Bool)
    func didConfirmSaveTemplate(name: String, context: ModelContext)
    func didTapLoadTemplate()
    func didSelectTemplate(_ template: SeatingLayoutTemplate)
    func didTapShare()
    func didSelectShareKind(_ kind: ShareSelectionKind)
    /// 広告準備状況を View（AdManager）から受け取り、route を更新する。
    /// 報酬獲得後の画像出力は `onReward` で View 側に戻す（Phase 4 で Router へ移管）。
    func didConfirmImageShareWithAd(isAdReady: Bool, onReward: @escaping () -> Void)
    func didRequestImageShare()
    func didTapSettings()
    func dismissRoute()

    func makeShareText() -> String

    /// シート dismiss 後に実行する共有種別（View が消費して nil にする）
    var pendingShareSelection: ShareSelectionKind? { get set }
    /// Unlock シート dismiss 後に広告を出すか
    var shouldShowAdOnDismiss: Bool { get set }
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

    /// Phase 4 で Gateway の `fetchCount` に置き換えるまでの暫定 API
    func templateSaveAvailability(currentCount: Int) -> TemplateSaveAvailability
    func makeLayoutTemplate(named name: String) -> LayoutTemplateSnapshot?
    func applyTemplate(_ snapshot: LayoutTemplateSnapshot) -> [SeatingTable]

    func makeShareText() -> String
    func shareImageRequirement() -> UnlockRequirement
}

// MARK: - Presenter -> Router

/// Phase 4 で実装を実体化する。
@MainActor
protocol SeatingChartRouterProtocol: AnyObject {
    func presentShareSheet(text: String)
    func presentShareSheet(image: UIImage)
    func presentRewardedAd() async throws
    func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView
    func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView
    func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView
}

// MARK: - Interactor -> Entity Gateway

protocol SeatingTemplateGateway {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [SeatingLayoutTemplate]
    func insert(_ template: SeatingLayoutTemplate) throws
    func delete(id: UUID) throws
}

nonisolated protocol FeatureUnlockGateway: AnyObject {
    var isSessionUnlocked: Bool { get }
    func grantSessionUnlock()
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
