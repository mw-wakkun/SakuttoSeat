//
//  GroupFavoriteGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//

import Foundation
import SwiftData

protocol GroupFavoriteGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [GroupFavorite]
    func insert(_ favorite: GroupFavorite) throws
    func delete(_ favorite: GroupFavorite) throws
    func delete(atOffsets offsets: IndexSet, in sortedFavorites: [GroupFavorite]) throws
}

nonisolated class GroupFavoriteGatewayBase: GroupFavoriteGateway {
    func fetchCount() throws -> Int { 0 }
    func fetchAll() throws -> [GroupFavorite] { [] }
    func insert(_ favorite: GroupFavorite) throws {}
    func delete(_ favorite: GroupFavorite) throws {}
    func delete(atOffsets offsets: IndexSet, in sortedFavorites: [GroupFavorite]) throws {}
}

nonisolated final class SwiftDataGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    override func fetchCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupFavorite>())
    }

    override func fetchAll() throws -> [GroupFavorite] {
        let descriptor = FetchDescriptor<GroupFavorite>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    override func insert(_ favorite: GroupFavorite) throws {
        context.insert(favorite)
        try context.save()
    }

    override func delete(_ favorite: GroupFavorite) throws {
        context.delete(favorite)
        try context.save()
    }

    override func delete(atOffsets offsets: IndexSet, in sortedFavorites: [GroupFavorite]) throws {
        for index in offsets where sortedFavorites.indices.contains(index) {
            context.delete(sortedFavorites[index])
        }
        try context.save()
    }
}

nonisolated final class InMemoryGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private(set) var favorites: [GroupFavorite] = []

    override func fetchCount() throws -> Int { favorites.count }

    override func fetchAll() throws -> [GroupFavorite] {
        favorites.sorted { $0.createdAt > $1.createdAt }
    }

    override func insert(_ favorite: GroupFavorite) throws {
        favorites.append(favorite)
    }

    override func delete(_ favorite: GroupFavorite) throws {
        favorites.removeAll { $0.id == favorite.id }
    }

    override func delete(atOffsets offsets: IndexSet, in sortedFavorites: [GroupFavorite]) throws {
        let ids = Set(offsets.compactMap { sortedFavorites.indices.contains($0) ? sortedFavorites[$0].id : nil })
        favorites.removeAll { ids.contains($0.id) }
    }
}
