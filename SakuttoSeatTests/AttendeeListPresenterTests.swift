//
//  AttendeeListPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0 / Phase 1
//  Presenter 経由の仲介と、複数削除バグの是正後挙動を固定する。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class AttendeeListPresenterTests: XCTestCase {

    private func makePresenter(
        names: [String] = [],
        gateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()
    ) -> AttendeeListPresenter {
        let interactor = AttendeeListInteractor()
        if !names.isEmpty {
            _ = interactor.add(fromText: names.joined(separator: ","))
        }
        let presenter = AttendeeListPresenter(interactor: interactor, router: AttendeeListRouter())
        presenter.attachFavoriteGateway(gateway)
        presenter.onAppear()
        return presenter
    }

    private func names(of presenter: AttendeeListPresenter) -> [String] {
        presenter.attendees.map(\.name)
    }

    // MARK: - 参加者

    func test_追加時に前後空白を除去する() {
        let presenter = makePresenter()

        presenter.didTapAddButton(name: "  佐藤  ")

        XCTAssertEqual(names(of: presenter), ["佐藤"])
    }

    func test_onAppearでInteractorの一覧を公開する() {
        let presenter = makePresenter(names: ["A", "B"])

        XCTAssertEqual(names(of: presenter), ["A", "B"])
    }

    func test_単一削除で指定行だけ消える() {
        let presenter = makePresenter(names: ["A", "B", "C"])

        presenter.didDeleteAttendee(at: IndexSet(integer: 1))

        XCTAssertEqual(names(of: presenter), ["A", "C"])
    }

    func test_複数削除はIndexSetを一度だけ適用する() {
        let presenter = makePresenter(names: ["A", "B", "C", "D"])

        presenter.didDeleteAttendee(at: IndexSet([0, 2]))

        XCTAssertEqual(names(of: presenter), ["B", "D"])
    }

    func test_リセットで全員削除する() {
        let presenter = makePresenter(names: ["A", "B"])

        presenter.didTapResetButton()

        XCTAssertTrue(presenter.attendees.isEmpty)
    }

    func test_一括追加の結果をそのまま公開する() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapBulkAddButton(text: "A,B")

        XCTAssertEqual(names(of: presenter), ["A", "A(2)", "B"])
    }

    // MARK: - お気に入り

    func test_お気に入り保存が可能ならavailableを返す() {
        let presenter = makePresenter(names: ["A"])

        XCTAssertEqual(presenter.favoriteSaveAvailability(), .available)
    }

    func test_お気に入りが上限に達するとlimitReachedを返す() {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didTapSaveFavoriteGroup(name: "グループ\(index)")
        }

        XCTAssertEqual(
            presenter.favoriteSaveAvailability(),
            .limitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            )
        )
    }

    func test_現在の参加者をお気に入りに保存する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["太郎", "花子"], gateway: gateway)

        presenter.didTapSaveFavoriteGroup(name: "同期")

        let saved = try gateway.fetchAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.name, "同期")
        XCTAssertEqual(saved.first?.members, ["太郎", "花子"])
    }

    func test_お気に入り選択で参加者リストを置換する() {
        let presenter = makePresenter(names: ["旧1", "旧2"])
        let group = GroupFavorite(name: "新メンバ", members: ["新1", "新2", "新3"])

        presenter.didSelectFavoriteGroup(group)

        XCTAssertEqual(names(of: presenter), ["新1", "新2", "新3"])
    }

    func test_メンバーが空のお気に入りを選ぶとリストが空になる() {
        let presenter = makePresenter(names: ["残したくない"])

        presenter.didSelectFavoriteGroup(GroupFavorite(name: "空", members: []))

        XCTAssertTrue(presenter.attendees.isEmpty)
    }

    func test_お気に入りをoffset指定で削除する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(gateway: gateway)
        presenter.didTapSaveFavoriteGroup(name: "古い")
        presenter.didTapSaveFavoriteGroup(name: "新しい")

        let before = try gateway.fetchAll()
        XCTAssertEqual(before.count, 2)
        let removedName = before[0].name

        presenter.didDeleteFavoriteGroups(at: IndexSet(integer: 0))

        let after = try gateway.fetchAll()
        XCTAssertEqual(after.count, 1)
        XCTAssertNotEqual(after.first?.name, removedName)
    }
}
