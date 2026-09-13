//
//  SimpleShuffleContracts.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 1（番号札の層間境界。空の RouterProtocol は置かない）
//  v2.1 Phase 3（発表のために Route を 1 本足す）
//

import Foundation

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
/// Protocol に載せると MainActor 隔離下の deinit で解放不整合が起きやすいため分離する。
@MainActor
protocol SimpleShufflePresenterProtocol: AnyObject {
    var viewData: SimpleShuffleViewData { get }
    var route: SimpleShuffleRoute? { get set }
    /// 共有フローは Share モジュールが担う（View はこの Presenter に `.shareFlow` を取り付ける）
    var share: SharePresenter { get }

    func didTapShuffle()
    func didTapShare()
    func didTapPresent()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol SimpleShuffleInteractorProtocol: AnyObject {
    func allSeats() -> [NumberedSeat]
    func shuffle() -> [NumberedSeat]
}
