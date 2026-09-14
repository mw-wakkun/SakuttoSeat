//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3 / Phase 4 / Phase 5
//  永続化は Interactor。遷移先の組み立ては Router へ委譲。
//  お気に入り一覧・一括追加は子モジュール。選択／確定は Output で受ける。
//  refactor_favorite.md Phase 3（シート組み立ては gatewayHolder。Presenter は Gateway 型を渡さない）
//  refactor_favorite.md Phase 4（`.favoriteList` 期間中は子 Presenter を 1 度だけ保持）
//  refactor_groupFavorite.md Phase 4（attach は Interactor のみ。PresenterProtocol からは外す）
//

import Combine
import SwiftUI

@MainActor
final class AttendeeListPresenter: ObservableObject, AttendeeListPresenterProtocol {
    @Published private(set) var viewData: AttendeeListViewData = .empty
    @Published var route: AttendeeListRoute?

    private let interactor: AttendeeListInteractor
    private let router: AttendeeListRouter

    /// `.favoriteList` 期間中だけ保持する。
    /// `.sheet(item:)` の content 再評価で再 assemble すると子の alert / 編集中状態が消えるため。
    /// `didTapShowFavorites` のたびに新規 assemble、閉じたら破棄（テストの Gateway 差し替え後の stale を防ぐ）。
    private(set) var favoriteGroupPresenter: FavoriteGroupPresenter?

    /// 上限到達後に名前確定済みなら、視聴成功後にその名前で保存する。
    private var pendingFavoriteName: String?

    /// 人数解放のあとで流し込む名前（一括／お気に入り溢れ、または＋で待っている1件）。
    private var pendingAttendeeNames: [String] = []
    /// リワード提示中。アラート閉鎖の dismiss で running task を殺さない。
    private var isPresentingVenueAd = false
    /// ＋からの1件待ちなら、視聴成功後に入力欄を空にする。
    private var shouldClearNameInputOnVenueUnlock = false
    /// 入力欄を空にするための世代。追加成功のときだけ進める。
    private var inputNonce = 0

    /// 広告待ちなど、画面寿命を超えて走らないようにする非同期作業。
    private var runningTask: Task<Void, Never>?
    /// 閉じたあとに完了した広告待ちが副作用を残さないための世代。
    private var runningTaskID = UUID()

    init(interactor: AttendeeListInteractor, router: AttendeeListRouter) {
        self.interactor = interactor
        self.router = router
        publishState()
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける
    nonisolated deinit {}

    func onAppear() {
        publishState()
    }

    @discardableResult
    func didTapAdd(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        switch interactor.attendeeCapacityDecision(addingCount: 1) {
        case .allowed:
            _ = interactor.add(name: trimmedName)
            consumeNameInput()
            publishState()
            return true
        case .requiresUnlock:
            pendingAttendeeNames = [trimmedName]
            shouldClearNameInputOnVenueUnlock = true
            setRoute(.alert(.attendeeUnlock(overflowTotal: nil, remainingFree: nil, remainingHard: nil)))
            publishState()
            return false
        case .blockedHardLimit:
            setRoute(.alert(.attendeeHardLimit))
            publishState()
            return false
        }
    }

    func didTapBulkAdd(text: String) {
        applyCappedResult(interactor.applyAttendeeAppendFromText(text))
    }

    func didDeleteAttendees(at offsets: IndexSet) {
        _ = interactor.remove(atOffsets: offsets)
        publishState()
    }

    func didTapReset() {
        setRoute(.alert(.confirmReset))
    }

    func didConfirmReset() {
        _ = interactor.removeAll()
        pendingAttendeeNames = []
        setRoute(nil)
        publishState()
    }

    func didTapSaveFavorite() {
        switch interactor.favoriteSaveAvailability() {
        case .available:
            setRoute(.saveFavoritePrompt)
        case .limitReached(let currentCount, let limit):
            setRoute(.alert(.favoriteLimitReached(currentCount: currentCount, limit: limit)))
        }
    }

    func didConfirmSaveFavorite(name: String) {
        do {
            try interactor.saveCurrentAsFavorite(named: name)
            pendingFavoriteName = nil
            setRoute(nil)
            publishState()
        } catch let error as FavoriteSaveError {
            switch error {
            case .limitReached(let currentCount, let limit):
                pendingFavoriteName = name
                setRoute(.alert(.favoriteLimitReached(currentCount: currentCount, limit: limit)))
            case .invalidName, .notFound:
                pendingFavoriteName = nil
                setRoute(nil)
            case .persistenceFailed(let message):
                pendingFavoriteName = nil
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            pendingFavoriteName = nil
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }

    /// 人数解放アラートで「動画を見て追加する」を選んだとき。お気に入り4枠目とは別経路。
    func didConfirmWatchVenueAd() {
        isPresentingVenueAd = true
        setRoute(nil)
        startRunningTask { [weak self] in
            await self?.confirmWatchVenueAd()
        }
    }

    /// 人数解放の結果をセッション解放とバッファ流し込みへ写す。テストはここを await する。
    /// 視聴成功後はアラート閉鎖による task キャンセルがあっても、解放とバッファ流し込みは落とさない。
    func confirmWatchVenueAd() async {
        isPresentingVenueAd = true
        setRoute(nil)
        let pending = pendingAttendeeNames
        let clearsInput = shouldClearNameInputOnVenueUnlock
        do {
            await router.waitUntilPresentable()
            try await router.presentRewardedAd()
            applyRewardedAttendeeUnlock(pending: pending, clearsInput: clearsInput)
        } catch RewardedAdError.notReady {
            isPresentingVenueAd = false
            setRoute(.alert(.adNotReady))
        } catch {
            isPresentingVenueAd = false
            // notEarned / failed / キャンセル: 会場拡張は立てない。バッファは残す。
        }
    }

    /// 上限アラートで「動画を見て1枠追加（今回だけ）」を選んだとき
    func didConfirmWatchAd() {
        // Binding の dismissRoute より先でも後でも名前を残す。ここでは dismissRoute を使わない。
        setRoute(nil)
        startRunningTask { [weak self] in
            await self?.confirmWatchAd()
        }
    }

    /// 上限アラートの OK。Binding より先に来ても確定済み名前とバイパスを捨てる。
    func didCancelFavoriteLimit() {
        cancelRunningTask()
        pendingFavoriteName = nil
        interactor.revokeOneTimeFavoriteSaveBypass()
        setRoute(nil)
    }

    /// 広告提示の結果を1回限り許可 / 保存へ写す。View は `didConfirmWatchAd` 経由。テストはここを await する。
    func confirmWatchAd() async {
        let taskID = runningTaskID
        do {
            await router.waitUntilPresentable()
            guard isCurrentTask(taskID) else { return }
            try await router.presentRewardedAd()
            guard isCurrentTask(taskID) else { return }
            interactor.grantOneTimeFavoriteSaveBypass()
            if let pendingFavoriteName {
                self.pendingFavoriteName = nil
                didConfirmSaveFavorite(name: pendingFavoriteName)
            } else {
                setRoute(.saveFavoritePrompt)
            }
        } catch RewardedAdError.notReady {
            guard isCurrentTask(taskID) else { return }
            setRoute(.alert(.adNotReady))
        } catch {
            // notEarned / failed / キャンセル: 上限はバイパスしない
        }
    }

    func didTapShowFavorites() {
        favoriteGroupPresenter = router.makeFavoriteGroupPresenter(
            gatewayHolder: interactor,
            output: self
        )
        setRoute(.favoriteList)
    }

    func didTapBulkAddEntry() {
        guard !isAttendeeHardLimited else {
            setRoute(.alert(.attendeeHardLimit))
            return
        }
        setRoute(.bulkAdd)
    }

    func didTapSeatingChart() {
        setRoute(.seatingChart)
    }

    func didTapSimpleShuffle() {
        setRoute(.simpleShuffle)
    }

    func dismissRoute() {
        let keepPendingFavoriteName = isFavoriteLimitAlert
        if !isAttendeeUnlockAlert && !isPresentingVenueAd {
            cancelRunningTask()
        }
        if !keepPendingFavoriteName {
            pendingFavoriteName = nil
            interactor.revokeOneTimeFavoriteSaveBypass()
        }
        setRoute(nil)
    }

    /// シートや画面が閉じられたときに、広告待ちなどの非同期作業を破棄する。
    func cancelRunningTask() {
        runningTask?.cancel()
        runningTask = nil
        runningTaskID = UUID()
    }

    /// ナビゲーション先を Router 経由で組み立てる（View から子モジュール型名を排除）
    func makeRouteView(_ route: AttendeeListRoute) -> AnyView {
        switch route {
        case .seatingChart:
            return router.makeSeatingChartModule(attendees: interactor.allAttendees())
        case .simpleShuffle:
            return router.makeSimpleShuffleModule(attendees: interactor.allAttendees())
        case .favoriteList, .bulkAdd, .saveFavoritePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    /// シート内容を Router 経由で組み立てる（SeatingChart の `makeRouteSheet` と同じ形）
    func makeRouteSheet(_ route: AttendeeListRoute) -> AnyView {
        switch route {
        case .favoriteList:
            return router.makeFavoriteGroupSheet(presenter: favoriteGroupSheetPresenter())
        case .bulkAdd:
            return router.makeBulkAddModule(output: self)
        case .seatingChart, .simpleShuffle, .saveFavoritePrompt, .alert:
            return AnyView(EmptyView())
        }
    }

    // MARK: - Private

    private func publishState(disablesAnimations: Bool = false) {
        let next = AttendeeListViewDataBuilder.build(
            attendees: interactor.allAttendees(),
            addControl: addControlState(from: interactor.attendeeCapacityDecision(addingCount: 1)),
            inputNonce: inputNonce
        )
        guard next != viewData else { return }
        if disablesAnimations {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                viewData = next
            }
        } else {
            viewData = next
        }
    }

    private func addControlState(from decision: CapacityDecision) -> AttendeeAddControlState {
        switch decision {
        case .allowed:
            return .available
        case .requiresUnlock:
            return .needsUnlock
        case .blockedHardLimit:
            return .hardLimited
        }
    }

    private func consumeNameInput() {
        inputNonce += 1
    }

    private func applyCappedResult(_ result: AttendeeAppendResult) {
        pendingAttendeeNames = result.overflowNames
        shouldClearNameInputOnVenueUnlock = false
        switch result.decision {
        case .allowed:
            setRoute(nil)
        case .requiresUnlock:
            setRoute(.alert(.attendeeUnlock(
                overflowTotal: result.triedCount,
                remainingFree: result.remainingFreeAtStart,
                remainingHard: result.remainingHardAtStart
            )))
        case .blockedHardLimit:
            if result.remainingHardAtStart > 0 {
                pendingAttendeeNames = []
                setRoute(.alert(.attendeeHardLimitOverflow(
                    triedCount: result.triedCount,
                    remainingHard: result.remainingHardAtStart
                )))
            } else {
                setRoute(.alert(.attendeeHardLimit))
            }
        }
        publishState()
    }

    /// 視聴成功後の解放とバッファ流し込み。
    /// `present()` は dismiss を MainActor で resume するので、次ランループへ送らずその場で反映する。
    /// 広告閉じるアニメーションに 80 人分の挿入を乗せるとボトムクロムがチラつくため、アニメーションは切る。
    private func applyRewardedAttendeeUnlock(pending: [String], clearsInput: Bool) {
        interactor.grantSessionUnlock()
        if pending.isEmpty {
            pendingAttendeeNames = []
            shouldClearNameInputOnVenueUnlock = false
            isPresentingVenueAd = false
            publishState(disablesAnimations: true)
            return
        }
        _ = interactor.applyAttendeeAppend(pending)
        pendingAttendeeNames = []
        shouldClearNameInputOnVenueUnlock = false
        if clearsInput {
            consumeNameInput()
        }
        isPresentingVenueAd = false
        publishState(disablesAnimations: true)
    }

    /// `didTapShowFavorites` で assemble 済みならそれを返す。未セットならここで 1 度だけ作る。
    private func favoriteGroupSheetPresenter() -> FavoriteGroupPresenter {
        if let favoriteGroupPresenter {
            return favoriteGroupPresenter
        }
        let assembled = router.makeFavoriteGroupPresenter(
            gatewayHolder: interactor,
            output: self
        )
        favoriteGroupPresenter = assembled
        return assembled
    }

    /// `.favoriteList` 以外へ移るときは子 Presenter を破棄する。
    private func setRoute(_ newRoute: AttendeeListRoute?) {
        if newRoute != .favoriteList {
            favoriteGroupPresenter = nil
        }
        route = newRoute
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

    /// SwiftUI の Alert Binding はボタン action より先に閉じることがある。
    /// 上限アラート閉鎖だけでは確定済み名前を捨てない（視聴成功後の自動保存用）。
    private var isFavoriteLimitAlert: Bool {
        if case .alert(.favoriteLimitReached) = route { return true }
        return false
    }

    private var isAttendeeUnlockAlert: Bool {
        if case .alert(.attendeeUnlock) = route { return true }
        return false
    }

    private var isAttendeeHardLimited: Bool {
        if case .blockedHardLimit = interactor.attendeeCapacityDecision(addingCount: 1) {
            return true
        }
        return false
    }
}

// MARK: - 子モジュール Output

extension AttendeeListPresenter: FavoriteGroupModuleOutput {
    func favoriteGroupDidSelect(id: FavoriteGroupID) {
        didSelectFavoriteGroup(id: id)
    }

    func favoriteGroupDidCancel() {
        dismissRoute()
    }

    private func didSelectFavoriteGroup(id: FavoriteGroupID) {
        do {
            let result = try interactor.loadFavorite(id: id)
            applyCappedResult(result)
        } catch FavoriteSaveError.notFound {
            return
        } catch let error as FavoriteSaveError {
            if case .persistenceFailed(let message) = error {
                setRoute(.alert(.saveFailed(message: message)))
            }
        } catch {
            setRoute(.alert(.saveFailed(message: error.localizedDescription)))
        }
    }
}

extension AttendeeListPresenter: BulkAddModuleOutput {
    func bulkAddDidConfirm(text: String) {
        didTapBulkAdd(text: text)
    }

    func bulkAddDidCancel() {
        dismissRoute()
    }
}
