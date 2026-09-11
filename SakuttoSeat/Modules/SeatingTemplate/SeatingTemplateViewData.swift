//
//  SeatingTemplateViewData.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（Copy と表示専用モデル。Entity / `@Model` はここに現れない）
//  文言自体は変えない。A11y Hint の対訳は Phase 6。
//

import Foundation

// MARK: - Copy

/// 画面・アラートの文言を 1 系統にまとめる。Catalog は ja のみ（翻訳 locale は増やさない）。
enum SeatingTemplateCopy {
    static var navigationTitle: String { String(localized: "テンプレート読込") }
    static var emptyMessage: String { String(localized: "保存されたテンプレートはありません") }
    static var edit: String { String(localized: "編集") }
    static var close: String { String(localized: "閉じる") }
    static var ok: String { String(localized: "OK") }
    static var deleteFailedTitle: String { String(localized: "削除に失敗しました") }
    static var loadFailedTitle: String { String(localized: "読み込みに失敗しました") }

    nonisolated static func tableCountLabel(_ count: Int) -> String {
        String(localized: "テーブル数: \(count)")
    }
}

// MARK: - ViewData

/// Presenter が生成し、View が消費する表示専用モデル。
/// Entity（`LayoutTemplateSnapshot`）はここに現れない。
nonisolated struct SeatingTemplateViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: SeatingTemplateID
        let name: String
        let tableCountLabel: String
    }

    let rows: [Row]
    var isEmpty: Bool { rows.isEmpty }

    static let empty = SeatingTemplateViewData(rows: [])
}

nonisolated enum SeatingTemplateViewDataBuilder {
    static func build(templates: [LayoutTemplateSnapshot]) -> SeatingTemplateViewData {
        SeatingTemplateViewData(
            rows: templates.map { template in
                SeatingTemplateViewData.Row(
                    id: template.id,
                    name: template.name,
                    tableCountLabel: SeatingTemplateCopy.tableCountLabel(template.tables.count)
                )
            }
        )
    }
}
