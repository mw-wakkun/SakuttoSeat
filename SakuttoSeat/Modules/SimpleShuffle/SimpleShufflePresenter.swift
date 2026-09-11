//
//  SimpleShufflePresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_AttendeeList.md Phase 5（ViewData 公開。withAnimation は View 側）
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

    init(interactor: SimpleShuffleInteractor, share: SharePresenter? = nil) {
        self.interactor = interactor
        self.share = share ?? ShareRouter.assemblePresenter()
        publishState()
    }

    func didTapShuffle() {
        _ = interactor.shuffle()
        publishState()
    }

    /// 共有はタップ時点の並び順を Share モジュールへ渡すだけ
    func didTapShare() {
        share.didTapShare(subject: .numberedList(attendees: viewData.rows.map(\.name)))
    }

    private func publishState() {
        viewData = SimpleShuffleViewDataBuilder.build(seats: interactor.allSeats())
    }
}
