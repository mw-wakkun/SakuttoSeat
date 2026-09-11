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

    /// 広告待ちなど、画面寿命を超えて走らないようにする非同期作業。
    private var runningTask: Task<Void, Never>?
    /// 閉じたあとに完了した広告待ちが副作用を残さないための世代。
    private var runningTaskID = UUID()

    init(interactor: ShareInteractor, router: ShareRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// 共有ボタンのタップ。共有対象はタップ時点の内容で固定する。
    func didTapShare(subject: ShareSubject) {
        cancelRunningTask()
        self.subject = subject
        route = .selection
    }

    func didSelectKind(_ kind: ShareSelectionKind) {
        route = nil
        guard let subject else { return }

        startRunningTask { [weak self] in
            let taskID = self?.runningTaskID
            await self?.router.waitUntilPresentable()
            guard let self, let taskID, self.isCurrentTask(taskID) else { return }

            switch kind {
            case .text:
                await self.router.presentShareSheet(text: self.interactor.makeShareText(for: subject))
            case .image:
                switch self.interactor.imageShareRequirement() {
                case .none:
                    await self.exportAndShareImage(for: subject)
                case .rewardedAd:
                    self.route = .alert(.confirmImageShareWithAd)
                }
            }
        }
    }

    func didConfirmImageShare() {
        route = nil
        guard let subject else { return }

        startRunningTask { [weak self] in
            await self?.confirmImageShare(for: subject)
        }
    }

    /// 広告提示の結果を Route / 画像出力へ写す。View は `didConfirmImageShare` 経由。テストはここを await する。
    func confirmImageShare(for subject: ShareSubject) async {
        let taskID = runningTaskID
        do {
            try await router.presentRewardedAd()
            guard isCurrentTask(taskID) else { return }
            await exportAndShareImage(for: subject)
        } catch RewardedAdError.notReady {
            guard isCurrentTask(taskID) else { return }
            route = .alert(.adNotReady)
        } catch {
            // notEarned / failed / キャンセル: 共有は行わない
        }
    }

    func dismissRoute() {
        cancelRunningTask()
        route = nil
    }

    /// シートや親画面が閉じられたときに、広告待ちなどの非同期作業を破棄する。
    func cancelRunningTask() {
        runningTask?.cancel()
        runningTask = nil
        runningTaskID = UUID()
    }

    private func exportAndShareImage(for subject: ShareSubject) async {
        guard let image = router.makeShareImage(for: subject) else {
            route = .alert(.imageExportFailed)
            return
        }
        await router.presentShareSheet(image: image)
    }

    private func startRunningTask(_ operation: @escaping @MainActor () async -> Void) {
        runningTask?.cancel()
        runningTaskID = UUID()
        runningTask = Task { @MainActor in
            await operation()
        }
    }

    private func isCurrentTask(_ taskID: UUID) -> Bool {
        runningTaskID == taskID && !Task.isCancelled
    }
}
