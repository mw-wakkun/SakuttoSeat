//
//  SimpleShufflePresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_simple.md Phase 1（Share は Router から注入。shuffle の戻りで ViewData を更新）
//  refactor_simple.md Phase 2（共有は ViewData をそのまま渡す）
//  v2.1 Phase 3（didTapPresent。発表中は share / shuffle の Route を出さない）
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class SimpleShufflePresenter: ObservableObject, SimpleShufflePresenterProtocol {
    @Published private(set) var viewData: SimpleShuffleViewData = .empty
    @Published var route: SimpleShuffleRoute?

    /// 共有フロー（Share モジュール）。View は `.shareFlow(presenter.share)` で取り付ける。
    let share: SharePresenter

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: SimpleShuffleInteractor
    private let router: SimpleShuffleRouter

    init(
        interactor: SimpleShuffleInteractor,
        share: SharePresenter,
        router: SimpleShuffleRouter? = nil
    ) {
        self.interactor = interactor
        self.share = share
        self.router = router ?? SimpleShuffleRouter()
        publishState(seats: interactor.allSeats())
    }

    func didTapShuffle() {
        guard !isPresenting else { return }
        publishState(seats: interactor.shuffle())
    }

    /// 共有はタップ時点の並び（ViewData）を Share モジュールへ渡すだけ
    func didTapShare() {
        guard !isPresenting else { return }
        share.didTapShare(subject: .numberedList(viewData))
    }

    /// 発表はタップ時点の ViewData を凍結して Cover する
    func didTapPresent() {
        guard !viewData.isEmpty, !isPresenting else { return }
        setRoute(.presentation(id: UUID(), snapshot: viewData))
    }

    func dismissRoute() {
        setRoute(nil)
    }

    /// 発表 Cover を Router 経由で組み立てる（空の VIPER は作らない）
    func makePresentationCover(_ route: SimpleShuffleRoute) -> AnyView {
        guard case .presentation(_, let snapshot) = route else {
            return AnyView(EmptyView())
        }
        return router.makePresentationCover(subject: .numberedList(snapshot)) { [weak self] in
            self?.dismissRoute()
        }
    }

    private var isPresenting: Bool {
        route?.presentsAsFullScreenCover == true
    }

    private func setRoute(_ newRoute: SimpleShuffleRoute?) {
        let wasPresenting = route?.presentsAsFullScreenCover == true
        let willPresent = newRoute?.presentsAsFullScreenCover == true
        if wasPresenting != willPresent {
            router.setIdleTimerDisabled(willPresent)
        }
        route = newRoute
    }

    private func publishState(seats: [NumberedSeat]) {
        viewData = SimpleShuffleViewDataBuilder.build(seats: seats)
    }
}
