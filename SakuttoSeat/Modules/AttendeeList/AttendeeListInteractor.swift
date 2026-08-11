//
//  AttendeeListInteractor.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import Foundation
import SwiftUI

protocol AttendeeListInteractorProtocol {
    /// 現在の参加者リストを返す
    func allAttendees() -> [Attendee]

    /// 指定された名前で参加者を1人追加する。先頭・末尾の空白を除去し、同名の場合は「(2)」「(3)」
    /// などを自動付与してユニークな名前を保証する。更新後のリストを返す。
    func add(name: String) -> [Attendee]

    /// 参加者をシャッフルする。最大3回試行して元の順序と異なることを保証し、更新後のリストを返す。
    func shuffle() -> [Attendee]

    /// 指定されたインデックスの参加者を削除し、更新後のリストを返す。
    func remove(atOffsets offsets: IndexSet) -> [Attendee]

    /// すべての参加者を削除して空にしたリストを返す。
    func removeAll() -> [Attendee]

    /// テキストからパースして複数の参加者を追加する。改行・カンマ（半角/全角）で分割され、
    /// 各エントリに対して add(name:) ロジックが適用される。
    func add(fromText text: String)
}

class AttendeeListInteractor: AttendeeListInteractorProtocol {
    // このモジュール用のメモリ内参加者ストレージ
    private var attendees: [Attendee] = []

    // MARK: - 公開 API
    func allAttendees() -> [Attendee] {
        return attendees
    }

    func add(name: String) -> [Attendee] {
        let trimmedName = trimmed(name)
        guard !trimmedName.isEmpty else { return attendees }

        let unique = generateUniqueName(from: trimmedName)
        attendees.append(Attendee(name: unique))
        return attendees
    }

    func shuffle() -> [Attendee] {
        guard attendees.count > 1 else { return attendees }

        let previous = attendees
        // 最大3回試行して同じ順序を避ける
        for _ in 0..<3 {
            attendees.shuffle()
            if attendees != previous { break }
        }
        return attendees
    }

    func remove(atOffsets offsets: IndexSet) -> [Attendee] {
        attendees.remove(atOffsets: offsets)
        return attendees
    }

    func removeAll() -> [Attendee] {
        attendees.removeAll()
        return attendees
    }

    func add(fromText text: String) {
        let names = splitRawNames(from: text)
        for name in names {
            _ = add(name: name)
        }
    }

    // MARK: - プライベートヘルパー
    /// 先頭・末尾の空白と改行を除去する
    private func trimmed(_ name: String) -> String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 必要に応じて末尾に (2), (3), ... を付与してユニーク名を生成する
    private func generateUniqueName(from base: String) -> String {
        var finalName = base
        var count = 2
        while attendees.contains(where: { $0.name == finalName }) {
            finalName = "\(base)(\(count))"
            count += 1
        }
        return finalName
    }

    /// テキストを改行とカンマ（半角/全角）で分割し、トリム済みの空でない名前のみを返す
    private func splitRawNames(from text: String) -> [String] {
        let rawNames = text.components(separatedBy: CharacterSet(charactersIn: "\n\r,、"))
        return rawNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
