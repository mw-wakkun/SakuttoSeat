//
//  SharePresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有フローの仲介）
//  refactor_Ad.md Phase 4（リワード分岐を await 可能なメソッドに切り出し、テストから駆動する）
//  v2.1 Phase 1（4択・書き出し解放。高画質レンダは Phase 2）
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
    /// 選択した書き出し形式。確認アラート後の出力先を決める。
    private(set) var selectedKind: ShareSelectionKind?

    /// 広告待ちなど、画面寿命を超えて走らないようにする非同期作業。
    private var runningTask: Task<Void, Never>?
    /// 閉じたあとに完了した広告待ちが副作用を残さないための世代。
    private var runningTaskID = UUID()

    init(interactor: ShareInteractor, router: ShareRouter) {
        self.interactor = interactor
        self.router = router
    }

    var isExportUnlocked: Bool {
        interactor.isExportUnlocked
    }

    /// 共有ボタンのタップ。共有対象はタップ時点の内容で固定する。
    func didTapShare(subject: ShareSubject) {
        cancelRunningTask()
        self.subject = subject
        selectedKind = nil
        route = .selection
    }

    func didSelectKind(_ kind: ShareSelectionKind) {
        route = nil
        guard let subject else { return }
        selectedKind = kind

        startRunningTask { [weak self] in
            let taskID = self?.runningTaskID
            await self?.router.waitUntilPresentable()
            guard let self, let taskID, self.isCurrentTask(taskID) else { return }

            await self.exportOrRequestUnlock(kind: kind, for: subject)
        }
    }

    func didConfirmExport() {
        route = nil
        guard let subject, let kind = selectedKind else { return }

        startRunningTask { [weak self] in
            await self?.confirmExport(for: subject, kind: kind)
        }
    }

    /// 選択後の広告要否分岐。View は `didSelectKind` 経由。テストはここを await する。
    func exportOrRequestUnlock(kind: ShareSelectionKind, for subject: ShareSubject) async {
        selectedKind = kind
        switch interactor.exportRequirement(for: kind) {
        case .none:
            route = nil
            await exportAndShare(kind: kind, subject: subject)
        case .rewardedAd:
            route = .alert(Self.confirmAlert(for: kind))
        }
    }

    /// 広告提示の結果を Route / 成果物へ写す。View は `didConfirmExport` 経由。テストはここを await する。
    func confirmExport(for subject: ShareSubject, kind: ShareSelectionKind) async {
        let taskID = runningTaskID
        do {
            try await router.presentRewardedAd()
            guard isCurrentTask(taskID) else { return }
            interactor.grantExportUnlock()
            await exportAndShare(kind: kind, subject: subject)
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

    private func exportAndShare(kind: ShareSelectionKind, subject: ShareSubject) async {
        switch kind {
        case .text:
            await router.presentShareSheet(text: interactor.makeShareText(for: subject))
        case .image, .highResImage:
            // Phase 2 で高画質レンダを分岐する。Phase 1 は標準画像と同じ経路。
            await exportAndShareImage(for: subject)
        case .csv:
            await exportAndShareCSV(for: subject)
        }
    }

    private func exportAndShareImage(for subject: ShareSubject) async {
        guard let image = router.makeShareImage(for: subject) else {
            route = .alert(.imageExportFailed)
            return
        }
        await router.presentShareSheet(image: image)
    }

    private func exportAndShareCSV(for subject: ShareSubject) async {
        let csv = interactor.makeCSV(for: subject)
        let fileName = interactor.makeCSVFileName(for: subject)
        let succeeded = await router.presentShareSheet(csv: csv, fileName: fileName)
        if !succeeded {
            route = .alert(.csvExportFailed)
        }
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

    private static func confirmAlert(for kind: ShareSelectionKind) -> ShareAlert {
        switch kind {
        case .text, .image:
            return .confirmImageShareWithAd
        case .highResImage:
            return .confirmHighResImageShareWithAd
        case .csv:
            return .confirmCSVExportWithAd
        }
    }
}
