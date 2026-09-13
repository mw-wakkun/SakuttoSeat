//
//  ShareContracts.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有フローの横断モジュール化）
//  refactor_simple.md Phase 2（番号札は SimpleShuffleViewData を渡す）
//  v2.1 Phase 1（4択・形式別確認・CSV 失敗）
//  v2.1 Phase 2（ExportQuality。高画質は PNG 一時ファイル）
//
//  座席表・番号札の 2 画面に重複していた共有フロー
//  （選択シート → 広告確認 → 画像出力 → シェアシート提示）を
//  このモジュールに 1 本化する。
//

import SwiftUI
import UIKit

// MARK: - 共有対象と選択肢

/// 共有方法の選択肢
enum ShareSelectionKind: Equatable, Hashable, CaseIterable {
    case text
    case image
    case highResImage
    case csv
}

/// 画像書き出しの画質。標準は画面の写し、高画質は余白カットの印刷向け。
enum ExportQuality: Equatable {
    case standard
    case highRes
}

/// 選択シート・確認アラートの文言。View が組み立て、Interactor は知らない。
enum ShareCopy {
    static func title(for kind: ShareSelectionKind) -> String {
        switch kind {
        case .text:
            return "テキストで共有"
        case .image:
            return "画像で共有"
        case .highResImage:
            return "高画質画像"
        case .csv:
            return "CSVで書き出す"
        }
    }

    static func subtitle(for kind: ShareSelectionKind, isExportUnlocked: Bool) -> String {
        switch kind {
        case .text:
            return "無料ですぐに共有できます"
        case .image, .highResImage, .csv:
            if isExportUnlocked {
                return "この起動中はすぐに書き出せます"
            }
            switch kind {
            case .image:
                return "動画を見てきれいな座席表画像を保存・送信"
            case .highResImage:
                return "余白カット・印刷や投影向き"
            case .csv:
                return "Excel・名簿ソフトで二次利用"
            case .text:
                return "無料ですぐに共有できます"
            }
        }
    }

    static func iconName(for kind: ShareSelectionKind) -> String {
        switch kind {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .highResImage:
            return "photo.badge.plus"
        case .csv:
            return "tablecells"
        }
    }

    static func confirmMessage(for kind: ShareSelectionKind) -> String {
        switch kind {
        case .text, .image:
            return "動画を見て、きれいな座席表画像を保存・送信しますか？"
        case .highResImage:
            return "動画を見て、余白を切った高画質画像を保存・送信しますか？"
        case .csv:
            return "動画を見て、Excelで開けるCSVを書き出しますか？"
        }
    }

    static let csvExportFailedTitle = "CSVの書き出しに失敗しました"
    static let csvExportFailedMessage = "CSVの書き出しに失敗しました。もう一度お試しください。"
    static let imageExportFailedTitle = "画像出力に失敗しました"
    static let imageExportFailedMessage = "画像の出力に失敗しました。もう一度お試しください。"
    static let rewardBadgeAccessibilityLabel = "動画の視聴が必要"
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
    case confirmHighResImageShareWithAd
    case confirmCSVExportWithAd
    case adNotReady
    case imageExportFailed
    case csvExportFailed

    var id: String {
        switch self {
        case .confirmImageShareWithAd:
            return "confirmImageShareWithAd"
        case .confirmHighResImageShareWithAd:
            return "confirmHighResImageShareWithAd"
        case .confirmCSVExportWithAd:
            return "confirmCSVExportWithAd"
        case .adNotReady:
            return "adNotReady"
        case .imageExportFailed:
            return "imageExportFailed"
        case .csvExportFailed:
            return "csvExportFailed"
        }
    }

    var isConfirmExport: Bool {
        switch self {
        case .confirmImageShareWithAd, .confirmHighResImageShareWithAd, .confirmCSVExportWithAd:
            return true
        case .adNotReady, .imageExportFailed, .csvExportFailed:
            return false
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
    func didConfirmExport()
    func dismissRoute()
}

// MARK: - Presenter -> Interactor

nonisolated protocol ShareInteractorProtocol: AnyObject {
    func makeShareText(for subject: ShareSubject) -> String
    func makeCSV(for subject: ShareSubject) -> String
    func exportRequirement(for kind: ShareSelectionKind) -> UnlockRequirement
    func grantExportUnlock()
    var isExportUnlocked: Bool { get }
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
protocol ShareRouterProtocol: AnyObject {
    @MainActor func waitUntilPresentable() async
    @MainActor func presentShareSheet(text: String) async
    @MainActor func presentShareSheet(image: UIImage) async
    @MainActor func presentShareSheet(fileURL: URL) async
    @MainActor func presentShareSheet(csv: String, fileName: String) async -> Bool
    @MainActor func presentShareSheet(pngImage: UIImage, fileName: String) async -> Bool
    @MainActor func presentRewardedAd() async throws
    @MainActor func makeShareImage(for subject: ShareSubject, quality: ExportQuality) -> UIImage?
}
