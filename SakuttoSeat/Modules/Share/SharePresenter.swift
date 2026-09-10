//
//  SharePresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有フローの仲介）
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
    private var subject: ShareSubject?

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
            do {
                try await router.presentRewardedAd()
                await exportAndShareImage(for: subject)
            } catch RewardedAdError.notReady {
                route = .alert(.adNotReady)
            } catch {
                // notEarned / failed: 共有は行わない
            }
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
