//
//  SimpleShuffleContracts.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 1（番号札の層間境界。空の RouterProtocol は置かない）
//

import Foundation

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
/// Protocol に載せると MainActor 隔離下の deinit で解放不整合が起きやすいため分離する。
@MainActor
protocol SimpleShufflePresenterProtocol: AnyObject {
    var viewData: SimpleShuffleViewData { get }
    /// 共有フローは Share モジュールが担う（View はこの Presenter に `.shareFlow` を取り付ける）
    var share: SharePresenter { get }

    func didTapShuffle()
    func didTapShare()
}

// MARK: - Presenter -> Interactor

nonisolated protocol SimpleShuffleInteractorProtocol: AnyObject {
    func allSeats() -> [NumberedSeat]
    func shuffle() -> [NumberedSeat]
}
