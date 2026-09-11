//
//  FavoriteGroupRouter.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（子モジュールの組み立て）
//

import SwiftUI

final class FavoriteGroupRouter {

    /// モジュールの組み立て（Builder 相当）。
    /// assemble 時点は In-Memory。実画面は View 初回 onAppear で SwiftData Gateway を渡す。
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
