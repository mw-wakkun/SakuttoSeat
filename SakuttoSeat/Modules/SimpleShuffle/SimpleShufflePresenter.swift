//
//  SimpleShufflePresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//

import SwiftUI
import Combine

@MainActor
class SimpleShufflePresenter: ObservableObject {
    @Published var attendees: [String]

    /// 共有フロー（Share モジュール）。View は `.shareFlow(presenter.share)` で取り付ける。
    let share: SharePresenter

    init(attendees: [String], share: SharePresenter? = nil) {
        // 初期表示時は登録順のまま保持（シャッフルはボタンタップ時のみ）
        self.attendees = attendees
        self.share = share ?? ShareRouter.assemblePresenter()
    }

    func didTapShuffleButton() {
        // .easeInOut よりも .spring の方が「シャッフルしてる感」が出ます
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            attendees.shuffle()
        }
    }

    /// 共有はタップ時点の並び順を Share モジュールへ渡すだけ
    func didTapShare() {
        share.didTapShare(subject: .numberedList(attendees: attendees))
    }
}
