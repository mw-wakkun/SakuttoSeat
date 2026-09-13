//
//  ShareInteractor.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有ペイロードの生成と広告要否の判断）
//  refactor_simple.md Phase 2（番号札テキストは ViewData.Row.number を使う）
//  v2.1 Phase 1（CSV 生成と書き出し解放。UIKit は見ない）
//  v2.1 Phase 2（高画質 PNG のファイル名。中身のレンダは Router）
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

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let exportUnlock: ExportUnlockState

    init(exportUnlock: ExportUnlockState = ExportUnlockState()) {
        self.exportUnlock = exportUnlock
    }

    var isExportUnlocked: Bool {
        exportUnlock.isSessionUnlocked
    }

    func makeShareText(for subject: ShareSubject) -> String {
        switch subject {
        case .seatingChart(let viewData):
            return makeSeatingChartText(tables: Self.tableContents(from: viewData))
        case .numberedList(let viewData):
            return makeNumberedListText(viewData: viewData)
        }
    }

    func makeCSV(for subject: ShareSubject) -> String {
        switch subject {
        case .seatingChart(let viewData):
            return makeSeatingChartCSV(tables: Self.tableContents(from: viewData))
        case .numberedList(let viewData):
            return makeNumberedListCSV(viewData: viewData)
        }
    }

    func makeCSVFileName(
        for subject: ShareSubject,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        exportFileName(for: subject, pathExtension: "csv", now: now, timeZone: timeZone)
    }

    func makePNGFileName(
        for subject: ShareSubject,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        exportFileName(for: subject, pathExtension: "png", now: now, timeZone: timeZone)
    }

    private func exportFileName(
        for subject: ShareSubject,
        pathExtension: String,
        now: Date,
        timeZone: TimeZone
    ) -> String {
        let stamp = Self.exportDateStamp(now: now, timeZone: timeZone)
        switch subject {
        case .seatingChart:
            return "座席表_\(stamp).\(pathExtension)"
        case .numberedList:
            return "番号札_\(stamp).\(pathExtension)"
        }
    }

    private static func exportDateStamp(now: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: now)
    }

    /// テキストは常に無料。有料3種は未解放ならリワード、解放後は不要。
    func exportRequirement(for kind: ShareSelectionKind) -> UnlockRequirement {
        switch kind {
        case .text:
            return .none
        case .image, .highResImage, .csv:
            return exportUnlock.isSessionUnlocked ? .none : .rewardedAd
        }
    }

    func grantExportUnlock() {
        exportUnlock.grantSessionUnlock()
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

    // MARK: - CSV

    /// UTF-8 BOM + LF。空席は出さない。ロック状態は出さない。
    func makeSeatingChartCSV(tables: [TableContent]) -> String {
        var lines = ["テーブル,行,列,氏名"]
        for table in tables {
            let colCount = max(1, table.columnCount)
            for (index, name) in table.memberNames.enumerated() {
                let row = (index / colCount) + 1
                let col = (index % colCount) + 1
                lines.append(
                    [csvEscape(table.name), "\(row)", "\(col)", csvEscape(name)].joined(separator: ",")
                )
            }
        }
        return Self.utf8BOM + lines.joined(separator: "\n")
    }

    func makeNumberedListCSV(viewData: SimpleShuffleViewData) -> String {
        var lines = ["番号,氏名"]
        for row in viewData.rows {
            lines.append(["\(row.number)", csvEscape(row.name)].joined(separator: ","))
        }
        return Self.utf8BOM + lines.joined(separator: "\n")
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

    // MARK: - CSV helpers

    static let utf8BOM = "\u{FEFF}"

    /// 氏名内のカンマ・引用符・改行を RFC 4180 相当でエスケープする
    func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
