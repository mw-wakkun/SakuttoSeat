//
//  AttendeeListRouter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_AttendeeList.md Phase 4（遷移・提示・子モジュール組み立て）
//

import SwiftUI

final class AttendeeListRouter: AttendeeListRouterProtocol {

    /// モジュールの初期組み立て（アプリ起動時などに使用）
    @MainActor
    static func assembleModule() -> some View {
        // assemble 時点は In-Memory。実画面は View 初回 onAppear で SwiftData Gateway を渡す。
        let interactor = AttendeeListInteractor()
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
    func makeFavoriteGroupModule(
        groups: [FavoriteGroupSnapshot],
        output: (any FavoriteGroupModuleOutput)?
    ) -> AnyView {
        AnyView(
            FavoriteGroupSheetView(
                groups: groups,
                onSelect: { id in
                    output?.favoriteGroupDidSelect(id: id)
                },
                onDelete: { offsets in
                    output?.favoriteGroupDidDelete(at: offsets)
                },
                onClose: {
                    output?.favoriteGroupDidCancel()
                }
            )
            .presentationDetents([.medium, .large])
        )
    }

    @MainActor
    func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView {
        AnyView(
            BulkAddSheetView(
                onConfirm: { text in
                    output?.bulkAddDidConfirm(text: text)
                },
                onCancel: {
                    output?.bulkAddDidCancel()
                }
            )
            .presentationDetents([.medium, .large])
        )
    }
}
