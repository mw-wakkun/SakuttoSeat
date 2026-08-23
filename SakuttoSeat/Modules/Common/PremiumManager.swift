//
//  PremiumManager.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/23.
//

import Foundation
import Combine

/// アプリ全体の課金状態を管理する。
/// v1.7.0 では課金未実装のため `isPro` は常に false。
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPro: Bool = false
    
    private init() {}
}
