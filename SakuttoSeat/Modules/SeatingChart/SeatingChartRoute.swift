//
//  SeatingChartRoute.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 2（ルーティング定義）
//

import Foundation

/// Presenter が単一の真実として保持する提示状態。
/// View の `@State` シート／アラートフラグ群をこれに集約する。
enum SeatingChartRoute: Identifiable, Equatable {
    case tableEdit(TableID)
    case venueSettings
    case templateList
    case saveTemplatePrompt
    case alert(SeatingChartAlert)

    var id: String {
        switch self {
        case .tableEdit(let tableID):
            return "tableEdit-\(tableID.uuidString)"
        case .venueSettings:
            return "venueSettings"
        case .templateList:
            return "templateList"
        case .saveTemplatePrompt:
            return "saveTemplatePrompt"
        case .alert(let alert):
            return "alert-\(alert.id)"
        }
    }

    /// `.sheet(item:)` で提示するケースか
    var presentsAsSheet: Bool {
        switch self {
        case .tableEdit, .venueSettings, .templateList:
            return true
        case .saveTemplatePrompt, .alert:
            return false
        }
    }

    /// `.alert` で提示するケースか（TextField 付きの保存プロンプトを含む）
    var presentsAsAlert: Bool {
        switch self {
        case .saveTemplatePrompt, .alert:
            return true
        default:
            return false
        }
    }
}

/// View が反応するキャンバス操作。`SeatingChartRoute` と同様に意味を持つイベントとして発行する。
enum SeatingChartCanvasEvent: Equatable, Identifiable {
    case scrollToTop(id: UUID)

    var id: UUID {
        switch self {
        case .scrollToTop(let id):
            return id
        }
    }

    static func scrollToTop() -> SeatingChartCanvasEvent {
        .scrollToTop(id: UUID())
    }
}

/// 画像共有・広告関連のアラートは Phase 5 で Share モジュール（`ShareAlert`）へ移した。
/// 列数解放のアラートは VenueSettings モジュール（`VenueSettingsRoute`）が持つ。
enum SeatingChartAlert: Equatable, Identifiable {
    case templateLimitReached(currentCount: Int, limit: Int)
    case saveFailed(message: String)

    var id: String {
        switch self {
        case .templateLimitReached:
            return "templateLimitReached"
        case .saveFailed:
            return "saveFailed"
        }
    }
}
