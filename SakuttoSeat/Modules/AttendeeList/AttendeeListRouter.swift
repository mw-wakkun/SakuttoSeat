//
//  AttendeeListRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 4 / Phase 5（遷移・提示・子モジュール組み立て）
//  refactor_favorite.md Phase 3（お気に入り子は gatewayHolder から現行 Gateway を読む）
//  refactor_favorite.md Phase 4（子 Presenter の組み立てとシート View を分離。キャッシュは親）
//  refactor_groupFavorite.md Phase 4（assemble 時点で Gateway を注入。デフォルトは InMemory）
//

import SwiftUI

final class AttendeeListRouter: AttendeeListRouterProtocol {

    /// モジュールの初期組み立て（アプリ起動時などに使用）。
    /// 本番は App が SwiftData Gateway を渡す。Preview / テストはデフォルトの InMemory。
    @MainActor
    static func assembleModule(
        favoriteGateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()
    ) -> some View {
        let interactor = AttendeeListInteractor(favoriteGateway: favoriteGateway)
        let router = AttendeeListRouter()
        let presenter = AttendeeListPresenter(
            interactor: interactor,
            router: router
        )
        return AttendeeListView(presenter: presenter)
    }

    // MARK: - 子モジュールの組み立て

    @MainActor
    func makeSeatingChartModule(attendees: [Attendee]) -> AnyView {
        SeatingChartRouter.assembleModule(attendees: attendees)
    }

    @MainActor
    func makeSimpleShuffleModule(attendees: [Attendee]) -> AnyView {
        SimpleShuffleRouter.assembleModule(attendees: attendees)
    }

    @MainActor
    func makeFavoriteGroupPresenter(
        gatewayHolder: AttendeeListInteractor,
        output: (any FavoriteGroupModuleOutput)?
    ) -> FavoriteGroupPresenter {
        FavoriteGroupRouter.assemblePresenter(
            favoriteGateway: gatewayHolder.currentFavoriteGateway(),
            output: output
        )
    }

    @MainActor
    func makeFavoriteGroupSheet(presenter: FavoriteGroupPresenter) -> AnyView {
        FavoriteGroupRouter.assembleView(presenter: presenter)
    }

    @MainActor
    func makeFavoriteGroupModule(
        gatewayHolder: AttendeeListInteractor,
        output: (any FavoriteGroupModuleOutput)?
    ) -> AnyView {
        FavoriteGroupRouter.assembleModule(
            favoriteGateway: gatewayHolder.currentFavoriteGateway(),
            output: output
        )
    }

    @MainActor
    func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView {
        BulkAddRouter.assembleModule(output: output)
    }
}
