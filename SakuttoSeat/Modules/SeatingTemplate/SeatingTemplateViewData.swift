//
//  SeatingTemplateViewData.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（Copy と表示専用モデル。Entity / `@Model` はここに現れない）
//  refactor_templateListView.md Phase 5（行は件数ラベルのみ）
//  refactor_templateListView.md Phase 6（閉じる / 編集 / 空状態 / 行の A11y。Catalog は ja のみ）
//  文言自体は変えない。
//

import Foundation

// MARK: - Copy

/// 画面・アラート・A11y の文言を 1 系統にまとめる。Catalog は ja のみ（翻訳 locale は増やさない）。
enum SeatingTemplateCopy {
    static var navigationTitle: String { String(localized: "テンプレート読込") }
    static var emptyMessage: String { String(localized: "保存されたテンプレートはありません") }
    static var emptyAccessibilityHint: String { String(localized: "閉じるボタンで座席表に戻ります") }
    static var selectAccessibilityHint: String { String(localized: "このテンプレートを座席表に読み込みます") }
    static var editingSelectDisabledHint: String { String(localized: "編集中は読み込みできません") }
    static var edit: String { String(localized: "編集") }
    static var editAccessibilityHint: String { String(localized: "テンプレートを削除できるようにします") }
    static var done: String { String(localized: "完了") }
    static var doneAccessibilityHint: String { String(localized: "編集を終了します") }
    static var close: String { String(localized: "閉じる") }
    static var closeAccessibilityHint: String { String(localized: "保存済みテンプレートの一覧を閉じます") }
    static var ok: String { String(localized: "OK") }
    static var deleteFailedTitle: String { String(localized: "削除に失敗しました") }
    static var loadFailedTitle: String { String(localized: "読み込みに失敗しました") }

    nonisolated static func tableCountLabel(_ count: Int) -> String {
        String(localized: "テーブル数: \(count)")
    }

    static func rowAccessibilityHint(isEditing: Bool) -> String {
        isEditing ? editingSelectDisabledHint : selectAccessibilityHint
    }

    static func editAccessibilityLabel(isEditing: Bool) -> String {
        isEditing ? done : edit
    }

    static func editButtonAccessibilityHint(isEditing: Bool) -> String {
        isEditing ? doneAccessibilityHint : editAccessibilityHint
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
