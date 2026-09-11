//
//  AttendeeListInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 3（お気に入り永続化・一括置換を Interactor へ）
//

import Foundation

nonisolated final class AttendeeListInteractor: AttendeeListInteractorProtocol {
    private var attendees: [Attendee] = []
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var favoriteGateway: GroupFavoriteGatewayBase

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

    func shuffle() -> [Attendee] {
        guard attendees.count > 1 else { return attendees }

        let previous = attendees
        // 最大3回試行して同じ順序を避ける
        for _ in 0..<3 {
            attendees.shuffle()
            if attendees != previous { break }
        }
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

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase) {
        favoriteGateway = gateway
    }

    func currentFavoriteGateway() -> GroupFavoriteGatewayBase {
        favoriteGateway
    }

    func favoriteSaveAvailability() -> FavoriteSaveAvailability {
        let currentCount = (try? favoriteGateway.fetchCount()) ?? 0
        if currentCount < FeatureLimit.freeFavoriteGroupCount {
            return .available
        }
        return .limitReached(currentCount: currentCount, limit: FeatureLimit.freeFavoriteGroupCount)
    }

    func saveCurrentAsFavorite(named name: String) throws {
        switch favoriteSaveAvailability() {
        case .limitReached(let currentCount, let limit):
            throw FavoriteSaveError.limitReached(currentCount: currentCount, limit: limit)
        case .available:
            break
        }

        let trimmedName = trimmed(name)
        guard !trimmedName.isEmpty else {
            throw FavoriteSaveError.invalidName
        }

        let favorite = GroupFavorite(name: trimmedName, members: attendees.map(\.name))
        do {
            try favoriteGateway.insert(favorite)
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func allFavorites() -> [FavoriteGroupSnapshot] {
        let favorites = (try? favoriteGateway.fetchAll()) ?? []
        return favorites.map { $0.makeSnapshot() }
    }

    func deleteFavorites(at offsets: IndexSet) throws {
        let currentList: [GroupFavorite]
        do {
            currentList = try favoriteGateway.fetchAll()
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }

        do {
            try favoriteGateway.delete(atOffsets: offsets, in: currentList)
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func loadFavorite(id: FavoriteGroupID) throws -> [Attendee] {
        let favorites: [GroupFavorite]
        do {
            favorites = try favoriteGateway.fetchAll()
        } catch {
            throw FavoriteSaveError.persistenceFailed(message: error.localizedDescription)
        }

        guard let favorite = favorites.first(where: { $0.id == id }) else {
            throw FavoriteSaveError.notFound
        }
        return replaceAll(names: favorite.members)
    }

    // MARK: - プライベートヘルパー

    /// 先頭・末尾の空白と改行を除去する
    private func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 一括追加・置換で名前集合を一度だけ作り、ユニーク名を O(n) に近づける
    private func appendUniqueNames(_ names: [String]) {
        var usedNames = Set(attendees.map(\.name))
        for name in names {
            let trimmedName = trimmed(name)
            guard !trimmedName.isEmpty else { continue }
            let unique = generateUniqueName(from: trimmedName, usedNames: &usedNames)
            attendees.append(Attendee(name: unique))
        }
    }

    /// 必要に応じて末尾に (2), (3), ... を付与してユニーク名を生成する
    private func generateUniqueName(from base: String, usedNames: inout Set<String>) -> String {
        var finalName = base
        var count = 2
        while usedNames.contains(finalName) {
            finalName = "\(base)(\(count))"
            count += 1
        }
        usedNames.insert(finalName)
        return finalName
    }

    /// テキストを改行とカンマ（半角/全角）で分割し、トリム済みの空でない名前のみを返す
    private func splitRawNames(from text: String) -> [String] {
        let rawNames = text.components(separatedBy: CharacterSet(charactersIn: "\n\r,、"))
        return rawNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
