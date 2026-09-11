//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 1（final 化・デッドコード削除・複数削除の修正）
//

import SwiftUI
import Combine

enum AttendeeListDestination: String, Identifiable, Hashable {
    case seatingChart
    case simpleShuffle

    var id: String { rawValue }
}

@MainActor
final class AttendeeListPresenter: ObservableObject {
    @Published private(set) var attendees: [Attendee] = []
    @Published var destination: AttendeeListDestination?

    private let interactor: AttendeeListInteractor
    private let router: AttendeeListRouter
    /// Protocol existential を MainActor クラスが保持すると deinit で malloc abort するため具象基底で保持する。
    private var favoriteGateway: GroupFavoriteGatewayBase = GroupFavoriteGatewayBase()

    init(interactor: AttendeeListInteractor, router: AttendeeListRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// @MainActor クラスの isolated deinit 経路での解放不整合を避ける
    nonisolated deinit {}

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
    }

    func onAppear() {
        attendees = interactor.allAttendees()
    }

    func didTapAddButton(name: String) {
        attendees = interactor.add(name: name)
    }

    func didDeleteAttendee(at offsets: IndexSet) {
        attendees = interactor.remove(atOffsets: offsets)
    }

    func didTapResetButton() {
        attendees = interactor.removeAll()
    }

    // MARK: - お気に入りグループ機能

    func favoriteSaveAvailability() -> TemplateSaveAvailability {
        let currentCount = (try? favoriteGateway.fetchCount()) ?? 0
        if currentCount < FeatureLimit.freeFavoriteGroupCount {
            return .available
        }
        return .limitReached(currentCount: currentCount, limit: FeatureLimit.freeFavoriteGroupCount)
    }

    /// 現在の参加者を新しいグループとしてお気に入りに保存する
    func didTapSaveFavoriteGroup(name: String) {
        let memberNames = attendees.map(\.name)
        let newFavorite = GroupFavorite(name: name, members: memberNames)
        do {
            try favoriteGateway.insert(newFavorite)
            print("お気に入りグループを保存しました: \(name), メンバー数: \(memberNames.count)")
        } catch {
            print("お気に入りグループの保存に失敗しました: \(error)")
        }
    }

    /// 選択されたお気に入りグループから参加者リストを上書き読み込みする
    func didSelectFavoriteGroup(_ group: GroupFavorite) {
        _ = interactor.removeAll()

        var updatedAttendees: [Attendee] = []
        for name in group.members {
            updatedAttendees = interactor.add(name: name)
        }

        attendees = updatedAttendees
    }

    func didDeleteFavoriteGroups(at offsets: IndexSet) {
        guard let currentList = try? favoriteGateway.fetchAll() else { return }
        do {
            try favoriteGateway.delete(atOffsets: offsets, in: currentList)
        } catch {
            print("お気に入りグループの削除に失敗しました: \(error)")
        }
    }

    // MARK: - ナビゲーション

    func view(for destination: AttendeeListDestination) -> AnyView {
        switch destination {
        case .seatingChart:
            return router.makeSeatingChartView(attendees: attendees)
        case .simpleShuffle:
            return router.makeSimpleShuffleView(attendees: attendees.map(\.name))
        }
    }

    func didTapBulkAddButton(text: String) {
        attendees = interactor.add(fromText: text)
    }
}
