//
//  SimpleShuffleRouter.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 1（番号札モジュールの組み立て。Share の生成もここが責務）
//
//  空 Protocol は旧 SeatingChart の失敗パターン。Builder は static assembleModule。
//  v2.1 Phase 3（発表 Cover の組み立てとアイドルタイマ。RouterProtocol は置かない）
//

import SwiftUI

final class SimpleShuffleRouter {

    /// モジュールの組み立て（Builder 相当）。親から `[Attendee]` を受け取り ID を維持する。
    /// Share は子モジュールとしてここで生成し、Presenter に注入する。
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SimpleShuffleInteractor(attendees: attendees)
        let share = ShareRouter.assemblePresenter()
        let router = SimpleShuffleRouter()
        let presenter = SimpleShufflePresenter(interactor: interactor, share: share, router: router)
        return AnyView(SimpleShuffleView(presenter: presenter))
    }

    /// 発表 Cover。空の RouterProtocol は置かず、組み立てとアイドルタイマだけ持つ。
    @MainActor
    func makePresentationCover(
        subject: PresentationSubject,
        onDismiss: @escaping () -> Void
    ) -> AnyView {
        AnyView(PresentationCanvas(subject: subject, onDismiss: onDismiss))
    }

    @MainActor
    func setIdleTimerDisabled(_ disabled: Bool) {
        IdleTimerController.setDisabled(disabled)
    }
}
