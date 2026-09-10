//
//  VenueSettingsContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子 VIPER モジュール化）
//

import Foundation

// MARK: - 表示専用モデル / ルーティング

struct VenueSettingsViewData: Equatable {
    let selectedColumnCount: Int
    let selectableRange: ClosedRange<Int>
    let noticeText: String
    /// 適用にリワード広告が必要かどうか（表示上の判断材料。判断そのものは Interactor）
    let requiresUnlock: Bool
}

enum VenueSettingsRoute: Identifiable, Equatable {
    case requireUnlock(requested: Int)
    case adNotReady

    var id: String {
        switch self {
        case .requireUnlock:
            return "requireUnlock"
        case .adNotReady:
            return "adNotReady"
        }
    }
}

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol VenueSettingsPresenterProtocol: AnyObject {
    var viewData: VenueSettingsViewData { get }
    var route: VenueSettingsRoute? { get set }

    func didChangeSelection(_ columnCount: Int)
    func didTapApply()
    func didConfirmWatchAd()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol VenueSettingsInteractorProtocol: AnyObject {
    var selectedColumnCount: Int { get }
    var selectableRange: ClosedRange<Int> { get }
    var isSessionUnlocked: Bool { get }

    @discardableResult func select(_ columnCount: Int) -> Int
    func applyRequirement() -> UnlockRequirement
    func grantSessionUnlock()
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
protocol VenueSettingsRouterProtocol: AnyObject {
    @MainActor func presentRewardedAd() async throws
}

// MARK: - Presenter -> 親モジュール

protocol VenueSettingsModuleOutput: AnyObject {
    func venueSettingsDidApply(columnCount: Int)
}
