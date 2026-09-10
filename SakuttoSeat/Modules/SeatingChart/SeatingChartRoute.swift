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
    case shareSelection
    case saveTemplatePrompt
    case unlockForSave
    case alert(SeatingChartAlert)

    var id: String {
        switch self {
        case .tableEdit(let tableID):
            return "tableEdit-\(tableID.uuidString)"
        case .venueSettings:
            return "venueSettings"
        case .templateList:
            return "templateList"
        case .shareSelection:
            return "shareSelection"
        case .saveTemplatePrompt:
            return "saveTemplatePrompt"
        case .unlockForSave:
            return "unlockForSave"
        case .alert(let alert):
            return "alert-\(alert.id)"
        }
    }

    /// `.sheet(item:)` で提示するケースか
    var presentsAsSheet: Bool {
        switch self {
        case .tableEdit, .venueSettings, .templateList, .shareSelection, .unlockForSave:
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

enum SeatingChartAlert: Equatable, Identifiable {
    case templateLimitReached(currentCount: Int, limit: Int)
    case confirmImageShareWithAd
    case adNotReady
    case requireUnlockForColumns(requested: Int)
    case saveFailed(message: String)
    case imageExportFailed

    var id: String {
        switch self {
        case .templateLimitReached:
            return "templateLimitReached"
        case .confirmImageShareWithAd:
            return "confirmImageShareWithAd"
        case .adNotReady:
            return "adNotReady"
        case .requireUnlockForColumns:
            return "requireUnlockForColumns"
        case .saveFailed:
            return "saveFailed"
        case .imageExportFailed:
            return "imageExportFailed"
        }
    }
}
