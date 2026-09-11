//
//  FavoriteGroupRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（子モジュールの組み立て）
//  refactor_favorite.md Phase 1（親が assemble 時に同じ Gateway を渡す）
//  refactor_favorite.md Phase 4（detent は組み立て側。キャッシュは持たない）
//

import SwiftUI

final class FavoriteGroupRouter {

    /// モジュールの組み立て（Builder 相当）。
    /// 親が assemble 時に同じ Gateway インスタンスを渡す（子 View は ModelContext を持たない）。
    /// シート detent はここで付ける（`SeatingChartRouter.makeTemplateListModule` と同じ位置）。
    /// インスタンスのキャッシュは持たない。シート identity は親 Presenter が route 期間中に保持する。
    @MainActor
    static func assemblePresenter(
        favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway(),
        output: (any FavoriteGroupModuleOutput)?
    ) -> FavoriteGroupPresenter {
        let interactor = FavoriteGroupInteractor(favoriteGateway: favoriteGateway)
        return FavoriteGroupPresenter(interactor: interactor, output: output)
    }

    @MainActor
    static func assembleView(presenter: FavoriteGroupPresenter) -> AnyView {
        AnyView(
            FavoriteGroupView(presenter: presenter)
                .presentationDetents([.medium, .large])
        )
    }

    @MainActor
    static func assembleModule(
        favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway(),
        output: (any FavoriteGroupModuleOutput)?
    ) -> AnyView {
        assembleView(
            presenter: assemblePresenter(
                favoriteGateway: favoriteGateway,
                output: output
            )
        )
    }
}
