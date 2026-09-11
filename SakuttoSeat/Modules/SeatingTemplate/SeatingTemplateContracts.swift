//
//  SeatingTemplateContracts.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2 / Phase 3（テンプレート一覧の子 VIPER モジュール）
//  一覧・削除は子。保存・読込適用は親。View は ViewData.Row と Route のみ。
//

import Foundation

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart / FavoriteGroup と同じ規約）。
@MainActor
protocol SeatingTemplatePresenterProtocol: AnyObject {
    var viewData: SeatingTemplateViewData { get }
    var route: SeatingTemplateRoute? { get set }

    func onAppear()
    func didSelectTemplate(id: SeatingTemplateID)
    func didDeleteTemplates(at offsets: IndexSet)
    func didTapClose()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol SeatingTemplateInteractorProtocol: AnyObject {
    func allTemplates() throws -> [LayoutTemplateSnapshot]
    func deleteTemplates(ids: [SeatingTemplateID]) throws
}

// MARK: - Presenter -> 親モジュール

protocol SeatingTemplateModuleOutput: AnyObject {
    func templateListDidSelect(id: SeatingTemplateID)
    func templateListDidCancel()
}
