//
//  SeatingTemplateRouter.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（子モジュールの組み立て）
//  親が assemble 時に同じ Gateway インスタンスを渡す（子 View は ModelContext を持たない）。
//  シート identity は Phase 4。この時点では毎回 assemble する。
//

import SwiftUI

final class SeatingTemplateRouter {

    /// モジュールの組み立て（Builder 相当）。
    /// 親が assemble 時に同じ Gateway インスタンスを渡す。
    /// シート detent はここで付ける（FavoriteGroupRouter と同じ位置）。
    /// インスタンスのキャッシュは持たない。
    @MainActor
    static func assemblePresenter(
        gateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway(),
        output: (any SeatingTemplateModuleOutput)?
    ) -> SeatingTemplatePresenter {
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)
        return SeatingTemplatePresenter(interactor: interactor, output: output)
    }

    @MainActor
    static func assembleView(presenter: SeatingTemplatePresenter) -> AnyView {
        AnyView(
            SeatingTemplateView(presenter: presenter)
                .presentationDetents([.medium, .large])
        )
    }

    @MainActor
    static func assembleModule(
        gateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway(),
        output: (any SeatingTemplateModuleOutput)?
    ) -> AnyView {
        assembleView(
            presenter: assemblePresenter(
                gateway: gateway,
                output: output
            )
        )
    }
}
