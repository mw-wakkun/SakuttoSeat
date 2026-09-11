//
//  SimpleShuffleRouter.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 1（番号札モジュールの組み立て。Share の生成もここが責務）
//
//  画面内遷移・提示のインスタンスメソッドは無いので RouterProtocol は置かない。
//  空 Protocol は旧 SeatingChart の失敗パターン。Builder は static assembleModule。
//

import SwiftUI

final class SimpleShuffleRouter {

    /// モジュールの組み立て（Builder 相当）。親から `[Attendee]` を受け取り ID を維持する。
    /// Share は子モジュールとしてここで生成し、Presenter に注入する。
    @MainActor
    static func assembleModule(attendees: [Attendee]) -> AnyView {
        let interactor = SimpleShuffleInteractor(attendees: attendees)
        let share = ShareRouter.assemblePresenter()
        let presenter = SimpleShufflePresenter(interactor: interactor, share: share)
        return AnyView(SimpleShuffleView(presenter: presenter))
    }
}
