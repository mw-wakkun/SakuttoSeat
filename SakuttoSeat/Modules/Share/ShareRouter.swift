//
//  ShareRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（シェアシート提示・広告提示・画像出力）
//  refactor_simple.md Phase 2（番号札画像も ViewData 駆動）
//  refactor_Ad.md Phase 2（リワードは Gateway 具象を assemble 時に注入）
//  refactor_Ad.md Phase 4（テストがシェアシート呼び出しを記録できるよう具象のまま継承可能にする）
//  v2.1 Phase 1（CSV 一時ファイル。高画質レンダは Phase 2）
//

import SwiftUI
import UIKit

/// テストがシェアシート提示を記録するため `final` にしない。Presenter は具象型のまま保持する。
class ShareRouter: ShareRouterProtocol {

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let rewardedAd: RewardedAdGatewayBase

    init(rewardedAd: RewardedAdGatewayBase) {
        self.rewardedAd = rewardedAd
    }

    /// モジュールの組み立て（Builder 相当）。呼び出し側の画面が Presenter を保持する。
    @MainActor
    static func assemblePresenter() -> SharePresenter {
        SharePresenter(
            interactor: ShareInteractor(exportUnlock: SessionExportUnlock.shared),
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
    func presentShareSheet(fileURL: URL) async {
        await ShareSheetPresenter.presentWhenReady(items: [fileURL]) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// CSV を一時ファイル化してシェアシートへ出す。書き込み失敗時は false。共有後にファイルを捨てる。
    @MainActor
    func presentShareSheet(csv: String, fileName: String) async -> Bool {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        await presentShareSheet(fileURL: url)
        return true
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await rewardedAd.present()
    }

    /// 出力に失敗したら nil を返し、Presenter がアラートを出す。
    /// Phase 1 は標準画像のみ。高画質オプションは Phase 2。
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
