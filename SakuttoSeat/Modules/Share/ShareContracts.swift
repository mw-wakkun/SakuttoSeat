//
//  ShareContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有フローの横断モジュール化）
//  refactor_simple.md Phase 2（番号札は SimpleShuffleViewData を渡す）
//
//  座席表・番号札の 2 画面に重複していた共有フロー
//  （選択シート → 広告確認 → 画像出力 → シェアシート提示）を
//  このモジュールに 1 本化する。
//

import SwiftUI
import UIKit

// MARK: - 共有対象と選択肢

/// 共有方法の選択肢
enum ShareSelectionKind {
    case text
    case image
}

/// 共有対象。呼び出し側の画面が「何を共有するか」だけを渡す。
enum ShareSubject: Equatable {
    /// 座席表（テキスト整形・画像出力の両方を表示専用モデルから作る）
    case seatingChart(SeatingChartViewData)
    /// 番号札（タップ時点の並び。表示専用モデルから作る）
    case numberedList(SimpleShuffleViewData)
}

// MARK: - ルーティング定義

/// 共有フローの提示状態。呼び出し側の画面はこの 1 本だけを監視する。
enum ShareRoute: Identifiable, Equatable {
    case selection
    case alert(ShareAlert)

    var id: String {
        switch self {
        case .selection:
            return "shareSelection"
        case .alert(let alert):
            return "shareAlert-\(alert.id)"
        }
    }
}

enum ShareAlert: Identifiable, Equatable {
    case confirmImageShareWithAd
    case adNotReady
    case imageExportFailed

    var id: String {
        switch self {
        case .confirmImageShareWithAd:
            return "confirmImageShareWithAd"
        case .adNotReady:
            return "adNotReady"
        case .imageExportFailed:
            return "imageExportFailed"
        }
    }
}

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol SharePresenterProtocol: AnyObject {
    var route: ShareRoute? { get set }

    func didTapShare(subject: ShareSubject)
    func didSelectKind(_ kind: ShareSelectionKind)
    func didConfirmImageShare()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol ShareInteractorProtocol: AnyObject {
    func makeShareText(for subject: ShareSubject) -> String
    func imageShareRequirement() -> UnlockRequirement
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
protocol ShareRouterProtocol: AnyObject {
    @MainActor func waitUntilPresentable() async
    @MainActor func presentShareSheet(text: String) async
    @MainActor func presentShareSheet(image: UIImage) async
    @MainActor func presentRewardedAd() async throws
    @MainActor func makeShareImage(for subject: ShareSubject) -> UIImage?
}
