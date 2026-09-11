//
//  GroupFavoriteGatewayTests.swift
//  SakuttoSeatTests
//
//  refactor_groupFavorite.md Phase 0（Gateway / Snapshot の characterization）
//  画面テストは FavoriteGroupTests / AttendeeList* に残し、永続化実装を直接固定する。
//

import SwiftData
import XCTest
@testable import SakuttoSeat

// MARK: - Gateway（In-Memory）

final class GroupFavoriteGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        try GroupFavoriteGatewayCases.assertNewestFirst(InMemoryGroupFavoriteGateway())
    }

    func test_insert後に件数が増える() throws {
        try GroupFavoriteGatewayCases.assertInsertIncrementsCount(InMemoryGroupFavoriteGateway())
    }

    func test_ID指定で1件取得する() throws {
        try GroupFavoriteGatewayCases.assertFetchByPersistedID(InMemoryGroupFavoriteGateway())
    }

    func test_存在しないIDの取得はnil() throws {
        try GroupFavoriteGatewayCases.assertMissingIDReturnsNil(InMemoryGroupFavoriteGateway())
    }

    func test_ID指定で削除する() throws {
        try GroupFavoriteGatewayCases.assertDeleteByID(InMemoryGroupFavoriteGateway())
    }

    func test_複数IDで削除する() throws {
        try GroupFavoriteGatewayCases.assertDeleteMultipleIDs(InMemoryGroupFavoriteGateway())
    }

    func test_存在しないIDの削除は無視される() throws {
        try GroupFavoriteGatewayCases.assertUnknownIDDeleteIsIgnored(InMemoryGroupFavoriteGateway())
    }

    func test_空のID配列の削除は何もしない() throws {
        try GroupFavoriteGatewayCases.assertEmptyIDsDeleteIsNoOp(InMemoryGroupFavoriteGateway())
    }

    func test_同一瞬間の連続insertでも新しい順を保つ() throws {
        try GroupFavoriteGatewayCases.assertConsecutiveInsertsKeepNewestFirst(
            InMemoryGroupFavoriteGateway()
        )
    }

    func test_memberSummaryはカンマ空白結合である() throws {
        try GroupFavoriteGatewayCases.assertMemberSummaryJoinsWithCommaSpace(
            InMemoryGroupFavoriteGateway()
        )
    }
}

// MARK: - Gateway（SwiftData In-Memory）

@MainActor
final class SwiftDataGroupFavoriteGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertNewestFirst(gateway)
    }

    func test_insert後に件数が増える() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertInsertIncrementsCount(gateway)
    }

    func test_ID指定で1件取得する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertFetchByPersistedID(gateway)
    }

    func test_uniqueなidがpersistとfetchで一致する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "同期", members: ["太郎"])

        let inserted = try XCTUnwrap(gateway.fetchAll().first)
        let fetched = try XCTUnwrap(gateway.fetch(id: inserted.id))

        XCTAssertEqual(fetched.id, inserted.id)
        XCTAssertEqual(try gateway.fetchAll().map(\.id), [inserted.id])
    }

    func test_存在しないIDの取得はnil() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertMissingIDReturnsNil(gateway)
    }

    func test_ID指定で削除する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertDeleteByID(gateway)
    }

    func test_複数IDで削除する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertDeleteMultipleIDs(gateway)
    }

    func test_存在しないIDの削除は無視される() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertUnknownIDDeleteIsIgnored(gateway)
    }

    func test_空のID配列の削除は何もしない() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertEmptyIDsDeleteIsNoOp(gateway)
    }

    func test_連続insertでも新しい順を保つ() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertConsecutiveInsertsKeepNewestFirst(gateway)
    }

    func test_memberSummaryはカンマ空白結合である() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try GroupFavoriteGatewayCases.assertMemberSummaryJoinsWithCommaSpace(gateway)
    }

    private func makeSwiftDataGateway() throws -> (SwiftDataGroupFavoriteGateway, ModelContainer) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: GroupFavorite.self,
            configurations: configuration
        )
        return (SwiftDataGroupFavoriteGateway(context: ModelContext(container)), container)
    }
}

// MARK: - GatewayBase（未 override は成功扱いで空）

final class GroupFavoriteGatewayBaseTests: XCTestCase {

    func test_未overrideは成功扱いで空を返す() throws {
        let gateway = GroupFavoriteGatewayBase()

        XCTAssertEqual(try gateway.fetchCount(), 0)
        XCTAssertTrue(try gateway.fetchAll().isEmpty)
        XCTAssertNil(try gateway.fetch(id: UUID()))

        try gateway.insert(name: "無視される", members: ["A"])
        XCTAssertEqual(try gateway.fetchCount(), 0)
        XCTAssertTrue(try gateway.fetchAll().isEmpty)

        try gateway.delete(ids: [UUID()])
        XCTAssertEqual(try gateway.fetchCount(), 0)
    }
}

// MARK: - Snapshot（Phase 2 で memberSummary を外すまでの現状固定）

final class FavoriteGroupSnapshotCharacterizationTests: XCTestCase {

    func test_persistedのmemberSummaryはカンマ空白結合である() {
        let snapshot = FavoriteGroupSnapshot.persisted(
            name: "同期",
            memberNames: ["太郎", "花子", "次郎"]
        )

        XCTAssertEqual(snapshot.memberSummary, "太郎, 花子, 次郎")
        XCTAssertEqual(snapshot.memberNames, ["太郎", "花子", "次郎"])
    }

    func test_空メンバーのmemberSummaryは空文字である() {
        let snapshot = FavoriteGroupSnapshot.persisted(name: "空", memberNames: [])

        XCTAssertEqual(snapshot.memberSummary, "")
        XCTAssertTrue(snapshot.memberNames.isEmpty)
    }
}

// MARK: - 共有ケース（InMemory / SwiftData の契約を同一にする）

private enum GroupFavoriteGatewayCases {

    static func assertNewestFirst(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "新しい", members: ["B", "C"])

        let groups = try gateway.fetchAll()
        XCTAssertEqual(groups.map(\.name), ["新しい", "古い"])
        XCTAssertEqual(groups.first?.memberNames, ["B", "C"])
    }

    static func assertInsertIncrementsCount(_ gateway: GroupFavoriteGateway) throws {
        XCTAssertEqual(try gateway.fetchCount(), 0)

        try gateway.insert(name: "1件目", members: ["A"])

        XCTAssertEqual(try gateway.fetchCount(), 1)
        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["1件目"])
    }

    static func assertFetchByPersistedID(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "同期", members: ["太郎", "花子"])
        let inserted = try XCTUnwrap(gateway.fetchAll().first)

        let fetched = try XCTUnwrap(gateway.fetch(id: inserted.id))

        XCTAssertEqual(fetched.id, inserted.id)
        XCTAssertEqual(fetched.name, "同期")
        XCTAssertEqual(fetched.memberNames, ["太郎", "花子"])
    }

    static func assertMissingIDReturnsNil(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "残る", members: ["A"])

        XCTAssertNil(try gateway.fetch(id: UUID()))
        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
    }

    static func assertDeleteByID(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "新しい", members: ["B"])
        let newerID = try XCTUnwrap(gateway.fetchAll().first?.id)

        try gateway.delete(ids: [newerID])

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["古い"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    static func assertDeleteMultipleIDs(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "真ん中", members: ["B"])
        try gateway.insert(name: "新しい", members: ["C"])
        let groups = try gateway.fetchAll()

        try gateway.delete(ids: [groups[0].id, groups[2].id])

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["真ん中"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    static func assertUnknownIDDeleteIsIgnored(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "残る", members: ["A"])

        try gateway.delete(ids: [UUID()])

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    static func assertEmptyIDsDeleteIsNoOp(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "残る", members: ["A"])

        try gateway.delete(ids: [])

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    static func assertConsecutiveInsertsKeepNewestFirst(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "1", members: ["A"])
        try gateway.insert(name: "2", members: ["B"])
        try gateway.insert(name: "3", members: ["C"])

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["3", "2", "1"])
    }

    static func assertMemberSummaryJoinsWithCommaSpace(_ gateway: GroupFavoriteGateway) throws {
        try gateway.insert(name: "同期", members: ["太郎", "花子"])

        XCTAssertEqual(try gateway.fetchAll().first?.memberSummary, "太郎, 花子")
    }
}
