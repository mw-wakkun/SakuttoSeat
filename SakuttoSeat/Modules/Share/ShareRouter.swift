//
//  ShareRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（シェアシート提示・広告提示・画像出力）
//  refactor_simple.md Phase 2（番号札画像も ViewData 駆動）
//  refactor_Ad.md Phase 2（リワードは Gateway 具象を assemble 時に注入）
//

import SwiftUI
import UIKit

final class ShareRouter: ShareRouterProtocol {

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let rewardedAd: RewardedAdGatewayBase

    init(rewardedAd: RewardedAdGatewayBase) {
        self.rewardedAd = rewardedAd
    }

    /// モジュールの組み立て（Builder 相当）。呼び出し側の画面が Presenter を保持する。
    @MainActor
    static func assemblePresenter() -> SharePresenter {
        SharePresenter(
            interactor: ShareInteractor(),
            router: ShareRouter(rewardedAd: SessionRewardedAd.shared)
        )
    }

    @MainActor
    func waitUntilPresentable() async {
        await ShareSheetPresenter.waitUntilPresentable()
    }

    @MainActor
    func presentShareSheet(text: String) async {
        await ShareSheetPresenter.presentWhenReady(items: [text])
    }

    @MainActor
    func presentShareSheet(image: UIImage) async {
        await ShareSheetPresenter.presentWhenReady(items: [image])
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await rewardedAd.present()
    }

    /// 出力に失敗したら nil を返し、Presenter がアラートを出す。
    @MainActor
    func makeShareImage(for subject: ShareSubject) -> UIImage? {
        switch subject {
        case .seatingChart(let viewData):
            return ImageExportRenderer.renderSeatingChart(viewData: viewData)
        case .numberedList(let viewData):
            return ImageExportRenderer.renderSimpleShuffle(viewData: viewData)
        }
    }
}
