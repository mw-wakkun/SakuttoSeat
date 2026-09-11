//
//  FavoriteGroupContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧の子 VIPER モジュール）
//

import Foundation

// MARK: - 表示専用モデル

struct FavoriteGroupViewData: Equatable {
    let groups: [FavoriteGroupSnapshot]
    let isEmpty: Bool

    static let empty = FavoriteGroupViewData(groups: [], isEmpty: true)
}

enum FavoriteGroupAlert: Equatable, Identifiable {
    case deleteFailed(message: String)

    var id: String {
        switch self {
        case .deleteFailed:
            return "deleteFailed"
        }
    }
}

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol FavoriteGroupPresenterProtocol: AnyObject {
    var viewData: FavoriteGroupViewData { get }
    var alert: FavoriteGroupAlert? { get set }

    func onAppear()
    func didSelectGroup(id: FavoriteGroupID)
    func didDeleteGroups(at offsets: IndexSet)
    func didTapClose()
    func dismissAlert()
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> Interactor

nonisolated protocol FavoriteGroupInteractorProtocol: AnyObject {
    func allFavorites() -> [FavoriteGroupSnapshot]
    func deleteFavorites(at offsets: IndexSet) throws
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: - Presenter -> 親モジュール

protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}
