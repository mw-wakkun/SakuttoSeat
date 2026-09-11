//
//  FavoriteGroupRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（子モジュールの組み立て）
//

import SwiftUI

final class FavoriteGroupRouter {

    /// モジュールの組み立て（Builder 相当）。
    /// 親が assemble 時に同じ Gateway インスタンスを渡す（子 View は ModelContext を持たない）。
    @MainActor
    static func assembleModule(
        favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway(),
        output: (any FavoriteGroupModuleOutput)?
    ) -> AnyView {
        let interactor = FavoriteGroupInteractor(favoriteGateway: favoriteGateway)
        let presenter = FavoriteGroupPresenter(interactor: interactor, output: output)
        return AnyView(FavoriteGroupView(presenter: presenter))
    }
}
