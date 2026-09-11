//
//  SimpleShuffleContracts.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（番号札の正式 VIPER）
//

import Foundation

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol SimpleShufflePresenterProtocol: AnyObject {
    var viewData: SimpleShuffleViewData { get }

    func didTapShuffle()
    func didTapShare()
}

// MARK: - Presenter -> Interactor

nonisolated protocol SimpleShuffleInteractorProtocol: AnyObject {
    func allSeats() -> [NumberedSeat]
    func shuffle() -> [NumberedSeat]
}
