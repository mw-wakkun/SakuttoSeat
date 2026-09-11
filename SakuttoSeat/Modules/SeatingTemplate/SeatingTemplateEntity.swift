//
//  SeatingTemplateEntity.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2 / Phase 3
//  共有型の所在。画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate。
//  Snapshot は子モジュール所有。親 SeatingChart は保存・適用にこれを使う。
//  一覧は Summary。tables は fetch(id:) だけ。
//

import Foundation

/// 保存済みレイアウトテンプレートの識別子。永続化モデル `SeatingLayoutTemplate.id` と同一。
typealias SeatingTemplateID = UUID

/// 読込適用（`fetch(id:)`）専用のスナップショット。表示用結合は持たない。
/// `tables` は適用に必要なレイアウト実体。
///
/// `nonisolated`: 既定の MainActor 隔離だと `nonisolated` な Interactor から生成できないため。
nonisolated struct LayoutTemplateSnapshot: Identifiable, Equatable {
    let id: SeatingTemplateID
    let name: String
    let tables: [TableTemplate]
    let globalColumnCount: Int

    /// 未永続化（`makeLayoutTemplate`）は `UUID()`。永続化後の id は Gateway が `@Model.id` から写す。
    init(
        id: SeatingTemplateID = UUID(),
        name: String,
        tables: [TableTemplate],
        globalColumnCount: Int
    ) {
        self.id = id
        self.name = name
        self.tables = tables
        self.globalColumnCount = globalColumnCount
    }
}

/// 一覧用 DTO。テーブル配列は持たない。件数ラベルは Gateway が載せる（Builder は写すだけ）。
nonisolated struct LayoutTemplateSummary: Identifiable, Equatable {
    let id: SeatingTemplateID
    let name: String
    let tableCountLabel: String
}
