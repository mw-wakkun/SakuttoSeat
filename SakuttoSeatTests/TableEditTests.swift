//
//  TableEditTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 5（TableEdit 子モジュールの回帰）
//
//  Phase 4 まで TableEditView の @State と .onChange が持っていた入力規則を
//  Interactor へ移送したため、規則はここで固定する。
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class TableEditInteractorTests: XCTestCase {

    private func makeInteractor(
        name: String = "テーブルA",
        capacity: Int = 4,
        columnCount: Int = 2,
        layoutDirection: LayoutDirection = .none,
        layoutText: String = ""
    ) -> TableEditInteractor {
        TableEditInteractor(
            draft: TableEditDraft(
                tableID: UUID(),
                name: name,
                capacity: capacity,
                columnCount: columnCount,
                layoutDirection: layoutDirection,
                layoutText: layoutText
            )
        )
    }

    func test_テーブル名は20文字で切り詰められる() {
        let interactor = makeInteractor()

        let draft = interactor.updateName(String(repeating: "あ", count: 25))

        XCTAssertEqual(draft.name.count, 20)
    }

    func test_ラベルも20文字で切り詰められる() {
        let interactor = makeInteractor()

        let draft = interactor.updateLayoutText(String(repeating: "窓", count: 30))

        XCTAssertEqual(draft.layoutText.count, 20)
    }

    func test_定員は1から10の範囲に収まる() {
        let interactor = makeInteractor()

        XCTAssertEqual(interactor.updateCapacity(0).capacity, 1)
        XCTAssertEqual(interactor.updateCapacity(99).capacity, 10)
    }

    func test_定員を減らすと列数も追従する() {
        let interactor = makeInteractor(capacity: 8, columnCount: 6)

        let draft = interactor.updateCapacity(3)

        XCTAssertEqual(draft.capacity, 3)
        XCTAssertEqual(draft.columnCount, 3)
    }

    func test_列数は定員を超えない() {
        let interactor = makeInteractor(capacity: 4, columnCount: 2)

        XCTAssertEqual(interactor.updateColumnCount(9).columnCount, 4)
        XCTAssertEqual(interactor.updateColumnCount(0).columnCount, 1)
        XCTAssertEqual(interactor.columnCountRange, 1...4)
    }

    func test_向きを指定なしにするとラベルが消える() {
        let interactor = makeInteractor(layoutDirection: .top, layoutText: "ステージ側")

        let draft = interactor.updateLayoutDirection(.none)

        XCTAssertEqual(draft.layoutDirection, .none)
        XCTAssertEqual(draft.layoutText, "")
    }

    func test_初期値も入力規則でクランプされる() {
        let interactor = makeInteractor(
            name: String(repeating: "あ", count: 25),
            capacity: 20,
            columnCount: 15
        )

        XCTAssertEqual(interactor.draft.name.count, 20)
        XCTAssertEqual(interactor.draft.capacity, 10)
        XCTAssertEqual(interactor.draft.columnCount, 10)
    }

    func test_保存リクエストは編集中の値と一括適用フラグを運ぶ() {
        let tableID = UUID()
        let interactor = TableEditInteractor(
            draft: TableEditDraft(tableID: tableID, name: "卓", capacity: 4, columnCount: 2)
        )
        interactor.updateName("幹事席")
        interactor.updateCapacity(6)
        interactor.updateColumnCount(3)
        interactor.updateLayoutDirection(.left)
        interactor.updateLayoutText("入り口側")
        interactor.updateApplyToAllTables(true)

        let request = interactor.makeUpdateRequest()

        XCTAssertEqual(
            request,
            TableUpdateRequest(
                tableID: tableID,
                name: "幹事席",
                capacity: 6,
                columnCount: 3,
                layoutDirection: .left,
                layoutText: "入り口側",
                applyToAll: true
            )
        )
    }
}

// MARK: - Presenter

@MainActor
final class TableEditPresenterTests: XCTestCase {

    private final class OutputSpy: TableEditModuleOutput {
        var committed: [TableUpdateRequest] = []
        var deleted: [TableID] = []
        var cancelCount = 0

        func tableEditDidCommit(_ request: TableUpdateRequest) { committed.append(request) }
        func tableEditDidRequestDelete(tableID: TableID) { deleted.append(tableID) }
        func tableEditDidCancel() { cancelCount += 1 }
    }

    private func makePresenter(
        tableID: TableID = UUID(),
        output: OutputSpy
    ) -> TableEditPresenter {
        TableEditPresenter(
            interactor: TableEditInteractor(
                draft: TableEditDraft(tableID: tableID, name: "テーブルA", capacity: 4, columnCount: 2)
            ),
            output: output
        )
    }

    func test_入力はViewDataへ反映される() {
        let output = OutputSpy()
        let presenter = makePresenter(output: output)

        presenter.didChangeName("幹事席")
        presenter.didChangeCapacity(6)
        presenter.didChangeColumnCount(3)
        presenter.didSelectLayoutDirection(.right)
        presenter.didChangeLayoutText("窓際")
        presenter.didToggleApplyToAllTables(true)

        XCTAssertEqual(presenter.viewData.name, "幹事席")
        XCTAssertEqual(presenter.viewData.capacity, 6)
        XCTAssertEqual(presenter.viewData.columnCount, 3)
        XCTAssertEqual(presenter.viewData.columnCountRange, 1...6)
        XCTAssertEqual(presenter.viewData.layoutDirection, .right)
        XCTAssertEqual(presenter.viewData.layoutText, "窓際")
        XCTAssertTrue(presenter.viewData.applyToAllTables)
    }

    func test_保存でOutputへリクエストが渡る() {
        let output = OutputSpy()
        let tableID = UUID()
        let presenter = makePresenter(tableID: tableID, output: output)

        presenter.didChangeName("幹事席")
        presenter.didTapSave()

        XCTAssertEqual(output.committed.count, 1)
        XCTAssertEqual(output.committed.first?.tableID, tableID)
        XCTAssertEqual(output.committed.first?.name, "幹事席")
    }

    func test_削除とキャンセルもOutputへ通知される() {
        let output = OutputSpy()
        let tableID = UUID()
        let presenter = makePresenter(tableID: tableID, output: output)

        presenter.didTapDelete()
        presenter.didTapCancel()

        XCTAssertEqual(output.deleted, [tableID])
        XCTAssertEqual(output.cancelCount, 1)
    }
}
