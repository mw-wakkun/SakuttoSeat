//
//  SeatingChartPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 3（仲介層としての Presenter 回帰）
//

import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import SakuttoSeat

@MainActor
private final class SeatingChartRouterSpy: SeatingChartRouterProtocol {
    func presentShareSheet(text: String) {}
    func presentShareSheet(image: UIImage) {}
    func presentRewardedAd() async throws {}
    func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView {
        AnyView(EmptyView())
    }
    func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView {
        AnyView(EmptyView())
    }
    func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView {
        AnyView(EmptyView())
    }
}

/// ドメイン判断は Interactor 側で固定する。ここでは ViewData / route / 永続化の仲介だけを検証する。
@MainActor
final class SeatingChartPresenterTests: XCTestCase {

    private func makePresenter(
        names: [String],
        featureUnlock: FeatureUnlockState? = nil
    ) -> SeatingChartPresenter {
        SeatingChartPresenter(
            interactor: SeatingChartInteractor(
                attendees: names.map { Attendee(name: $0) },
                featureUnlock: featureUnlock
            ),
            router: SeatingChartRouterSpy()
        )
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SeatingLayoutTemplate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func firstTableID(in presenter: SeatingChartPresenter) -> TableID {
        for row in presenter.viewData.rows {
            for item in row.items {
                if case .table(let table) = item {
                    return table.id
                }
            }
        }
        XCTFail("テーブルが1つもない")
        return UUID()
    }

    func test_テーブル編集の確定でViewDataが更新され先頭へスクロールする() {
        let presenter = makePresenter(names: ["A", "B"])
        let tableID = firstTableID(in: presenter)

        presenter.didCommitTableEdit(
            TableUpdateRequest(
                tableID: tableID,
                name: "幹事席",
                capacity: 2,
                columnCount: 2,
                layoutDirection: .top,
                layoutText: "ステージ側",
                applyToAll: false
            )
        )

        if case .table(let table) = presenter.viewData.rows[0].items[0] {
            XCTAssertEqual(table.name, "幹事席")
            XCTAssertEqual(table.badge, .top)
        } else {
            XCTFail("先頭はテーブルであるべき")
        }
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("編集確定後は先頭へスクロールする")
        }
    }

    func test_テンプレート適用で会場列数がViewDataに反映され先頭へスクロールする() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"])
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        presenter.applyTemplate(template)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("テンプレート適用後は先頭へスクロールする")
        }
    }

    func test_テンプレート保存_無料枠は3件までで4件目から保存不可になる() throws {
        let context = try makeInMemoryContext()
        let presenter = makePresenter(names: ["A", "B"])

        XCTAssertTrue(presenter.canSaveTemplate(context: context))

        presenter.saveLayoutAsTemplate(templateName: "1件目", context: context)
        presenter.saveLayoutAsTemplate(templateName: "2件目", context: context)
        XCTAssertTrue(presenter.canSaveTemplate(context: context))

        presenter.saveLayoutAsTemplate(templateName: "3件目", context: context)
        XCTAssertFalse(presenter.canSaveTemplate(context: context))

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertEqual(saved.count, 3)
    }

    func test_テンプレート保存_現在のレイアウトと会場列数が保存される() throws {
        let context = try makeInMemoryContext()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"])
        presenter.sessionUnlockedColumns = true
        presenter.globalColumnCount = 3

        presenter.saveLayoutAsTemplate(templateName: "歓迎会", context: context)

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].name, "歓迎会")
        XCTAssertEqual(saved[0].globalColumnCount, 3)
        XCTAssertEqual(saved[0].tables.map(\.name), ["テーブルA", "テーブルB"])
        XCTAssertEqual(saved[0].tables.map(\.capacity), [4, 4])
    }

    func test_テンプレート保存_名前が空白のみなら保存されない() throws {
        let context = try makeInMemoryContext()
        let presenter = makePresenter(names: ["A"])

        presenter.saveLayoutAsTemplate(templateName: "   ", context: context)

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertTrue(saved.isEmpty)
    }

    func test_セッション解放フラグはGatewayへ委譲される() {
        let gateway = FeatureUnlockState()
        let presenter = makePresenter(names: ["A"], featureUnlock: gateway)

        XCTAssertFalse(presenter.sessionUnlockedColumns)
        presenter.sessionUnlockedColumns = true
        XCTAssertTrue(presenter.sessionUnlockedColumns)
        XCTAssertTrue(gateway.isSessionUnlocked)
    }

    func test_共有テキストはInteractorに委譲される() {
        let presenter = makePresenter(names: ["太郎"])
        let text = presenter.makeShareText()
        XCTAssertTrue(text.contains("太郎"))
        XCTAssertTrue(text.contains("#サクッと席決め"))
    }
}
