//
//  SeatingTemplateInteractor.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2 / Phase 3
//  一覧の取得・削除は子 Interactor が Gateway を持つ（保存・読込適用は親）。
//  Gateway は Snapshot を返す。@Model はこの層に現れない。
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
            return try templateGateway.fetchAll()
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }

    func deleteTemplates(ids: [SeatingTemplateID]) throws {
        do {
            try templateGateway.delete(ids: ids)
        } catch {
            throw TemplateSaveError.persistenceFailed(message: error.localizedDescription)
        }
    }
}
