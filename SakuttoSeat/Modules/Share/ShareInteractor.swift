//
//  ShareInteractor.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有ペイロードの生成と広告要否の判断）
//  refactor_simple.md Phase 2（番号札テキストは ViewData.Row.number を使う）
//
//  もとは SeatingChartView / SimpleShuffleView / SeatingChartInteractor に
//  分散していた共有テキストの整形をここへ集約する。
//

import Foundation

nonisolated final class ShareInteractor: ShareInteractorProtocol {

    /// テキスト整形の入力。特定モジュールの Entity に依存しない中立な形。
    struct TableContent: Equatable {
        let name: String
        let columnCount: Int
        let memberNames: [String]
    }

    func makeShareText(for subject: ShareSubject) -> String {
        switch subject {
        case .seatingChart(let viewData):
            return makeSeatingChartText(tables: Self.tableContents(from: viewData))
        case .numberedList(let viewData):
            return makeNumberedListText(viewData: viewData)
        }
    }

    /// 画像共有は常にリワード広告が必要
    func imageShareRequirement() -> UnlockRequirement {
        .rewardedAd
    }

    // MARK: - テキスト整形

    func makeSeatingChartText(tables: [TableContent]) -> String {
        var text = "【サクッと席決め】座席表のシャッフル結果です！\n\n"

        for table in tables {
            text += "━━━━━━━━━━━━━━━━━\n"
            text += "▼ \(table.name)\n"
            text += "━━━━━━━━━━━━━━━━━\n"

            let colCount = max(1, table.columnCount)

            if table.memberNames.isEmpty {
                text += "（まだメンバーが配置されていません）\n"
            } else {
                for (index, name) in table.memberNames.enumerated() {
                    let row = (index / colCount) + 1
                    let col = (index % colCount) + 1

                    if colCount == 2 {
                        let side = (index % 2 == 0) ? "左" : "右"
                        text += "🪑 [\(row)列目 · \(side)] : \(name)\n"
                    } else {
                        text += "🪑 [\(row)行\(col)列目] : \(name)\n"
                    }
                }
            }
            text += "\n"
        }

        text += "#サクッと席決め"
        return text
    }

    func makeNumberedListText(viewData: SimpleShuffleViewData) -> String {
        var text = "【サクッと席決め】シャッフル結果\n"
        for row in viewData.rows {
            text += "\(row.number)番席: \(row.name)\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 表示専用モデルからの取り出し

    /// 追加ボタンと空席パディングを除き、テーブルの並び順どおりに取り出す
    static func tableContents(from viewData: SeatingChartViewData) -> [TableContent] {
        viewData.rows
            .flatMap(\.items)
            .compactMap { item in
                guard case .table(let table) = item else { return nil }
                return TableContent(
                    name: table.name,
                    columnCount: table.columnCount,
                    memberNames: table.seats.filter { !$0.isEmpty }.map(\.displayName)
                )
            }
    }
}
