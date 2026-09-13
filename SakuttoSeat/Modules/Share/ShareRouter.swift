//
//  ShareRouter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（シェアシート提示・広告提示・画像出力）
//  refactor_simple.md Phase 2（番号札画像も ViewData 駆動）
//  refactor_Ad.md Phase 2（リワードは Gateway 具象を assemble 時に注入）
//  refactor_Ad.md Phase 4（テストがシェアシート呼び出しを記録できるよう具象のまま継承可能にする）
//  v2.1 Phase 1（CSV 一時ファイル）
//  v2.1 Phase 2（高画質は quality 付きレンダ + PNG 一時ファイル）
//  v2.1 Phase 2 hotfix（ファイル提示失敗を呼び出し側へ返す）
//  v2.0 hotfix（標準画像のシェアシート提示前に waitUntilPresentable）
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
        await waitUntilPresentable()
        await ShareSheetPresenter.presentWhenReady(items: [image])
    }

    @MainActor
    func presentShareSheet(fileURL: URL) async {
        _ = await presentShareFile(fileURL)
    }

    /// CSV を一時ファイル化してシェアシートへ出す。書き込み・提示失敗時は false。共有後にファイルを捨てる。
    @MainActor
    func presentShareSheet(csv: String, fileName: String) async -> Bool {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        return await presentShareFile(url)
    }

    @MainActor
    func presentRewardedAd() async throws {
        try await rewardedAd.present()
    }

    /// 高画質 PNG を一時ファイル化してシェアシートへ出す。書き込み・提示失敗時は false。共有後にファイルを捨てる。
    @MainActor
    func presentShareSheet(pngImage: UIImage, fileName: String) async -> Bool {
        guard let url = ImageExportRenderer.writeTemporaryPNG(pngImage, fileName: fileName) else {
            return false
        }
        return await presentShareFile(url)
    }

    /// 一時ファイルをシェアシートへ出す。提示できなければファイルを捨てて false。
    @MainActor
    private func presentShareFile(_ url: URL) async -> Bool {
        let presented = await ShareSheetPresenter.presentWhenReady(items: [url]) {
            try? FileManager.default.removeItem(at: url)
        }
        if !presented {
            try? FileManager.default.removeItem(at: url)
        }
        return presented
    }

    /// 出力に失敗したら nil を返し、Presenter がアラートを出す。
    @MainActor
    func makeShareImage(for subject: ShareSubject, quality: ExportQuality = .standard) -> UIImage? {
        switch subject {
        case .seatingChart(let viewData):
            return ImageExportRenderer.renderSeatingChart(viewData: viewData, quality: quality)
        case .numberedList(let viewData):
            return ImageExportRenderer.renderSimpleShuffle(viewData: viewData, quality: quality)
        }
    }
}
