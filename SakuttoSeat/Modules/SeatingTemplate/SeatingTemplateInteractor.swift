//
//  SeatingTemplateInteractor.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2
//  一覧の取得・削除は子 Interactor が Gateway を持つ（保存・読込適用は親）。
//  Gateway はまだ `@Model` を返す。Snapshot への写像はこの層が担う（Phase 3 で Gateway へ移す）。
//  削除は旧 API `delete(id:)` を ID 配列で回す（Phase 3 で `delete(ids:)` に切り替える）。
//

import Foundation

nonisolated final class SeatingTemplateInteractor: SeatingTemplateInteractorProtocol {
    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private var templateGateway: SeatingTemplateGatewayBase

    init(templateGateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway()) {
        self.templateGateway = templateGateway
    }

    /// テスト用の差し替え。本番は assemble 時に注入済み。
    func attachTemplateGateway(_ gateway: SeatingTemplateGatewayBase) {
        templateGateway = gateway
    }

    func allTemplates() throws -> [LayoutTemplateSnapshot] {
        do {
            return try templateGateway.fetchAll().map(Self.makeSnapshot)
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func deleteTemplates(ids: [SeatingTemplateID]) throws {
        do {
            for id in ids {
                try templateGateway.delete(id: id)
            }
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    private static func makeSnapshot(from template: SeatingLayoutTemplate) -> LayoutTemplateSnapshot {
        LayoutTemplateSnapshot(
            id: template.id,
            name: template.name,
            tables: template.tables,
            globalColumnCount: template.globalColumnCount
        )
    }
}
