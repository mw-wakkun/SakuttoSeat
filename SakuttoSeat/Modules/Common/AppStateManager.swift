//
//  AppStateManager.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/17.
//

import SwiftUI
import Combine

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    /// 4つ目以降の登録アンロックフラグ（動画視聴済み）
    @AppStorage("hasUnlockedUnlimitedGroups") var hasUnlockedUnlimitedGroups: Bool = false
    
    /// 将来のPro版ユーザーフラグ
    @AppStorage("isProUser") var isProUser: Bool = false
    
    /// 無料で保存できる上限数
    let defaultMaxFreeCount = 3
    
    private init() {}
    
    /// グループが保存可能かどうかを判定
    func canSaveMoreGroups(currentCount: Int) -> Bool {
        if isProUser || hasUnlockedUnlimitedGroups {
            return true
        }
        return currentCount < defaultMaxFreeCount
    }
}
