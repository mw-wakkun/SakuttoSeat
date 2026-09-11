//
//  SeatingChartEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/06.
//

import Foundation

typealias TableID = UUID
typealias MemberID = UUID

// テーブルの向き（方向）を表す列挙型。
// 表示用のテキストは別プロパティ（layoutText）で扱うため、
// この列挙型は「方向」だけを表現します。
enum LayoutDirection: String, CaseIterable, Identifiable, Codable, Equatable, Hashable {
    case none = "指定なし"
    case top = "上"
    case bottom = "下"
    case left = "左"
    case right = "右"

    var id: String { self.rawValue }
}

/// 会場全体の設定（Phase 3 で Interactor が真実の所在になる）
///
/// `nonisolated`: 既定の MainActor 隔離だと `static let default` を
/// `nonisolated` な Interactor から参照できないため。
nonisolated struct VenueSettings: Equatable, Hashable {
    var globalColumnCount: Int
    var defaultCapacity: Int
    var defaultColumnCount: Int

    static let `default` = VenueSettings(
        globalColumnCount: 2,
        defaultCapacity: 4,
        defaultColumnCount: 2
    )
}

/// テーブル編集のリクエスト（Phase 5 で子モジュール Output から渡す）
///
/// `nonisolated`: `TableEditInteractor`（nonisolated）が生成し、
/// `SeatingChartInteractor`（nonisolated）が受け取るため。
nonisolated struct TableUpdateRequest: Equatable {
    let tableID: TableID
    let name: String
    let capacity: Int
    let columnCount: Int
    let layoutDirection: LayoutDirection
    let layoutText: String
    let applyToAll: Bool
}

/// 列数変更や画像共有などに必要な解放条件
///
/// `nonisolated`: Interactor（nonisolated）の戻り値として使うため。
nonisolated enum UnlockRequirement: Equatable {
    case none
    case rewardedAd
}

/// 会場列数の適用に失敗した理由
enum VenueSettingsError: Error, Equatable {
    case unlockRequired(requested: Int)
}

/// テンプレート保存の可否
enum TemplateSaveAvailability: Equatable {
    case available
    case limitReached(currentCount: Int, limit: Int)
}

/// テンプレート保存の失敗理由
enum TemplateSaveError: Error, Equatable {
    case limitReached(currentCount: Int, limit: Int)
    case invalidName
    case emptyLayout
    case notFound
    case persistenceFailed(message: String)
}

/// 永続化モデル（SwiftData）を Interactor から隔離するためのスナップショット
///
/// `id` は Phase 2 で必須化した。未永続化（`makeLayoutTemplate`）は `UUID()` で埋める。
/// Equatable / 所在の `SeatingTemplateEntity` 移設は Phase 3。
/// `nonisolated`: 既定の MainActor 隔離だと `nonisolated` な Interactor から生成できないため。
nonisolated struct LayoutTemplateSnapshot {
    let id: UUID
    let name: String
    let tables: [TableTemplate]
    let globalColumnCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        tables: [TableTemplate],
        globalColumnCount: Int
    ) {
        self.id = id
        self.name = name
        self.tables = tables
        self.globalColumnCount = globalColumnCount
    }
}

// 参加者モデル
//
// `nonisolated`: `SeatingTable`（nonisolated）の Equatable / Hashable 合成に必要。
nonisolated struct SeatingMember: Identifiable, Equatable, Hashable {
    let id: MemberID
    let name: String
    var isLocked: Bool = false
}

// テーブルモデル
//
// `nonisolated`: 既定の MainActor 隔離だと明示 init を
// `nonisolated` な Interactor から呼べないため。
nonisolated struct SeatingTable: Identifiable, Equatable, Hashable {
    let id: TableID
    var name: String
    var capacity: Int // 定員
    var columnCount: Int // 横の列数
    // 方向と表示テキストを分離
    var layoutDirection: LayoutDirection
    var layoutText: String
    var assignedMembers: [SeatingMember]

    init(
        id: TableID = UUID(),
        name: String,
        capacity: Int,
        columnCount: Int = 2,
        layoutDirection: LayoutDirection = .none,
        layoutText: String = "",
        assignedMembers: [SeatingMember] = []
    ) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.columnCount = columnCount
        self.layoutDirection = layoutDirection
        self.layoutText = layoutText
        self.assignedMembers = assignedMembers
    }
}
