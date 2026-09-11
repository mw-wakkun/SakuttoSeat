//
//  SeatingTemplateInteractor.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2 / Phase 3
//  一覧の取得・削除は子 Interactor が Gateway を持つ（保存・読込適用は親）。
//  一覧は fetchSummaries。Snapshot 相当へは写さない。@Model はこの層に現れない。
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

    func allTemplates() throws -> [LayoutTemplateSummary] {
        do {
            return try templateGateway.fetchSummaries()
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
