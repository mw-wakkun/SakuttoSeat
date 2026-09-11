//
//  SeatingTemplateEntity.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2 / Phase 3
//  共有型の所在。画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate。
//  Snapshot は子モジュール所有。親 SeatingChart は保存・適用にこれを使う。
//

import Foundation

/// 保存済みレイアウトテンプレートの識別子。永続化モデル `SeatingLayoutTemplate.id` と同一。
typealias SeatingTemplateID = UUID

/// 永続化モデル（SwiftData）を View / Presenter から隔離するスナップショット。
/// 一覧描画用の件数ラベルは ViewData Builder が担う。`tables` は適用に必要なレイアウト実体。
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
