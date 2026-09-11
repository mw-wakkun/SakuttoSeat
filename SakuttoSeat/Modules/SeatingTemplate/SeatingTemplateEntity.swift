//
//  SeatingTemplateEntity.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（共有型の所在。画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate）
//
//  `LayoutTemplateSnapshot` は Phase 3 まで親 Entity に残す。本ファイルは ID のみ。
//

import Foundation

/// 保存済みレイアウトテンプレートの識別子。永続化モデル `SeatingLayoutTemplate.id` と同一。
typealias SeatingTemplateID = UUID
