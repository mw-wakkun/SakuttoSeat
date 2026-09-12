//
//  AttendeeListInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3 / Phase 6（お気に入り永続化・一括置換。ユニーク名は O(n)）
//  refactor_favorite.md Phase 3（保存・読込置換のみ。一覧・削除は子。load は fetch(id:)）
//  refactor_groupFavorite.md Phase 4（本番 Gateway は assemble 時注入。attach はテスト用）
//  refactor_groupFavorite.md Phase 5（Gateway 呼び出しは MainActor Presenter 経由のみ）
//

import Foundation

/// Gateway 呼び出しは本番では `@MainActor` Presenter 経由のみ。
/// Interactor 自体は `nonisolated`（VIPER 規約）。型で MainActor は強制しない。
nonisolated final class AttendeeListInteractor: AttendeeListInteractorProtocol {
    private var attendees: [Attendee] = []
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var favoriteGateway: GroupFavoriteGatewayBase
    /// リワード視聴成功で付与する、上限超過の1回限り許可。永続解放ではない。
    private var allowsOneTimeLimitBypass = false

    init(favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()) {
        self.favoriteGateway = favoriteGateway
    }

    // MARK: - 参加者

    func allAttendees() -> [Attendee] {
        attendees
    }

    func add(name: String) -> [Attendee] {
        appendUniqueNames([name])
        return attendees
    }

    func add(fromText text: String) -> [Attendee] {
        appendUniqueNames(splitRawNames(from: text))
        return attendees
    }

    func replaceAll(names: [String]) -> [Attendee] {
        attendees.removeAll()
        appendUniqueNames(names)
        return attendees
    }

    func remove(atOffsets offsets: IndexSet) -> [Attendee] {
        // `RangeReplaceableCollection.remove(atOffsets:)` は SwiftUI の拡張のため使わない
        for index in offsets.sorted(by: >) where attendees.indices.contains(index) {
            attendees.remove(at: index)
        }
        return attendees
    }

    func removeAll() -> [Attendee] {
        attendees.removeAll()
        return attendees
    }

    // MARK: - お気に入り

    /// テスト用の差し替え。本番は assemble 時に注入済み。View 経路からは呼ばない。
    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
    }

    /// Router が子モジュール組み立て時に同じインスタンスを渡すための供給口。
    /// Presenter の公開面には出さない。
    func currentFavoriteGateway() -> GroupFavoriteGatewayBase {
        favoriteGateway
    }

    func favoriteSaveAvailability() -> FavoriteSaveAvailability {
        if allowsOneTimeLimitBypass {
            return .available
        }
        let currentCount = (try? favoriteGateway.fetchCount()) ?? 0
        if currentCount < FeatureLimit.freeFavoriteGroupCount {
            return .available
        }
        return .limitReached(currentCount: currentCount, limit: FeatureLimit.freeFavoriteGroupCount)
    }

    /// 広告視聴成功後に呼ぶ。上限そのものは変えず、次の1回の保存だけ許可する。
    func grantOneTimeFavoriteSaveBypass() {
        allowsOneTimeLimitBypass = true
    }

    /// 保存成功・キャンセルで1回限り許可を捨てる。無料枠内の保存でも消費する。
    func revokeOneTimeFavoriteSaveBypass() {
        allowsOneTimeLimitBypass = false
    }

    func saveCurrentAsFavorite(named name: String) throws {
        let currentCount = (try? favoriteGateway.fetchCount()) ?? 0
        let isOverFreeLimit = currentCount >= FeatureLimit.freeFavoriteGroupCount
        if isOverFreeLimit && !allowsOneTimeLimitBypass {
            throw FavoriteSaveError.limitReached(
                currentCount: currentCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            )
        }

        let trimmedName = trimmed(name)
        guard !trimmedName.isEmpty else {
            throw FavoriteSaveError.invalidName
        }

        do {
            try favoriteGateway.insert(name: trimmedName, members: attendees.map(\.name))
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }

        allowsOneTimeLimitBypass = false
    }

    func loadFavorite(id: FavoriteGroupID) throws -> [Attendee] {
        let favorite: FavoriteGroupSnapshot?
        do {
            favorite = try favoriteGateway.fetch(id: id)
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }

        guard let favorite else {
            throw FavoriteSaveError.notFound
        }
        return replaceAll(names: favorite.memberNames)
    }

    // MARK: - プライベートヘルパー

    /// 先頭・末尾の空白と改行を除去する
    private func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 一括追加・置換で名前集合を一度だけ作り、連番探索をベース名ごとに継続して O(n) にする
    private func appendUniqueNames(_ names: [String]) {
        var usedNames = Set(attendees.map(\.name))
        var nextIndexByBase: [String: Int] = [:]
        for name in names {
            let trimmedName = trimmed(name)
            guard !trimmedName.isEmpty else { continue }
            let unique = uniquedName(trimmedName, usedNames: &usedNames, nextIndexByBase: &nextIndexByBase)
            attendees.append(Attendee(name: unique))
        }
    }

    /// 必要に応じて末尾に (2), (3), ... を付与してユニーク名を生成する
    private func uniquedName(
        _ base: String,
        usedNames: inout Set<String>,
        nextIndexByBase: inout [String: Int]
    ) -> String {
        if usedNames.insert(base).inserted {
            nextIndexByBase[base] = 2
            return base
        }
        var index = nextIndexByBase[base, default: 2]
        var candidate = "\(base)(\(index))"
        while !usedNames.insert(candidate).inserted {
            index += 1
            candidate = "\(base)(\(index))"
        }
        nextIndexByBase[base] = index + 1
        return candidate
    }

    /// テキストを改行とカンマ（半角/全角）で分割し、トリム済みの空でない名前のみを返す
    private func splitRawNames(from text: String) -> [String] {
        let rawNames = text.components(separatedBy: CharacterSet(charactersIn: "\n\r,、"))
        return rawNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
