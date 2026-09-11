//
//  SharePresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有フローの仲介）
//  refactor_Ad.md Phase 4（リワード分岐を await 可能なメソッドに切り出し、テストから駆動する）
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class SharePresenter: ObservableObject, SharePresenterProtocol {
    @Published var route: ShareRoute?

    /// protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象型で保持する。
    private let interactor: ShareInteractor
    private let router: ShareRouter
    /// タップ時点の共有対象。本番は内部利用のみ。テストから payload を検証するために読み取り可能。
    private(set) var subject: ShareSubject?

    init(interactor: ShareInteractor, router: ShareRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// 共有ボタンのタップ。共有対象はタップ時点の内容で固定する。
    func didTapShare(subject: ShareSubject) {
        self.subject = subject
        route = .selection
    }

    func didSelectKind(_ kind: ShareSelectionKind) {
        route = nil
        guard let subject else { return }

        Task { @MainActor in
            // 選択シートが閉じ終わるまで待ってから次の提示に移る
            await router.waitUntilPresentable()
            switch kind {
            case .text:
                await router.presentShareSheet(text: interactor.makeShareText(for: subject))
            case .image:
                switch interactor.imageShareRequirement() {
                case .none:
                    await exportAndShareImage(for: subject)
                case .rewardedAd:
                    route = .alert(.confirmImageShareWithAd)
                }
            }
        }
    }

    func didConfirmImageShare() {
        route = nil
        guard let subject else { return }

        Task { @MainActor in
            await confirmImageShare(for: subject)
        }
    }

    /// 広告提示の結果を Route / 画像出力へ写す。View は `didConfirmImageShare` 経由。テストはここを await する。
    func confirmImageShare(for subject: ShareSubject) async {
        do {
            try await router.presentRewardedAd()
            await exportAndShareImage(for: subject)
        } catch RewardedAdError.notReady {
            route = .alert(.adNotReady)
        } catch {
            // notEarned / failed: 共有は行わない
        }
    }

    func dismissRoute() {
        route = nil
    }

    private func exportAndShareImage(for subject: ShareSubject) async {
        guard let image = router.makeShareImage(for: subject) else {
            route = .alert(.imageExportFailed)
            return
        }
        await router.presentShareSheet(image: image)
    }
}
