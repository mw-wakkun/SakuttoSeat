//
//  SeatingChartContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 2（モジュール契約）
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
    var scrollToTopTrigger: Int { get }

    /// 会場列数（Phase 3 で Interactor / VenueSettings へ移送）
    var globalColumnCount: Int { get set }
    /// セッション限定の列数解放（Phase 3 で FeatureUnlockGateway へ移送）
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

    /// 共有テキスト（Phase 5 で Share / Interactor へ移送）
    func makeShareText() -> String

    /// シート dismiss 後に実行する共有種別（View が消費して nil にする）
    var pendingShareSelection: ShareSelectionKind? { get set }
    /// Unlock シート dismiss 後に広告を出すか
    var shouldShowAdOnDismiss: Bool { get set }
}

// MARK: - Presenter -> Interactor

/// 現行 API。Phase 3 で状態保持型の §4.1 API に置換する。
///
/// Phase 3 での目標シグネチャ（参考）:
/// - `currentTables() / currentVenueSettings()`
/// - `buildInitialTables / shuffleSeats / reassignInRegistrationOrder / toggleLock`
/// - `addTable / deleteTable / updateTable / updateAllTables`
/// - `columnCountChangeRequirement / applyColumnCount / grantSessionUnlock`
/// - `templateSaveAvailability / saveCurrentLayoutAsTemplate / applyTemplate`
/// - `makeShareText / shareImageRequirement`
protocol SeatingChartInteractorProtocol: AnyObject {
    func shuffleAndAssign(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable]
    func assignInRegistrationOrder(attendees: [Attendee], to tables: [SeatingTable]) -> [SeatingTable]
}

// MARK: - Presenter -> Router

/// Phase 4 で実装を実体化する。Phase 2 ではスタブで契約だけ先に固定する。
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

protocol FeatureUnlockGateway: AnyObject {
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
