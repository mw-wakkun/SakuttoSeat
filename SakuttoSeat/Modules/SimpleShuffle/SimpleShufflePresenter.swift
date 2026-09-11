//
//  SimpleShufflePresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_simple.md Phase 1（Share は Router から注入。shuffle の戻りで ViewData を更新）
//  refactor_simple.md Phase 2（共有は ViewData をそのまま渡す）
//

import Combine
import Foundation

@MainActor
final class SimpleShufflePresenter: ObservableObject, SimpleShufflePresenterProtocol {
    @Published private(set) var viewData: SimpleShuffleViewData = .empty

    /// 共有フロー（Share モジュール）。View は `.shareFlow(presenter.share)` で取り付ける。
    let share: SharePresenter

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: SimpleShuffleInteractor

    init(interactor: SimpleShuffleInteractor, share: SharePresenter) {
        self.interactor = interactor
        self.share = share
        publishState(seats: interactor.allSeats())
    }

    func didTapShuffle() {
        publishState(seats: interactor.shuffle())
    }

    /// 共有はタップ時点の並び（ViewData）を Share モジュールへ渡すだけ
    func didTapShare() {
        share.didTapShare(subject: .numberedList(viewData))
    }

    private func publishState(seats: [NumberedSeat]) {
        viewData = SimpleShuffleViewDataBuilder.build(seats: seats)
    }
}
