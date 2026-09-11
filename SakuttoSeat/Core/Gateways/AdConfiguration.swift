//
//  AdConfiguration.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 1（バナー / リワードのユニット ID を 1 箇所に集約）
//

import Foundation

/// 広告ユニット ID。DEBUG は Google 公式サンプル、RELEASE は本番。
///
/// `nonisolated`: バナー Representable / Gateway 実装の両方から読むため。
nonisolated enum AdConfiguration {
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let rewardedUnitID = "ca-app-pub-3940256099942544/5224354917"
    #else
    static let bannerUnitID = "ca-app-pub-9676260030977388/3254679876"
    static let rewardedUnitID = "ca-app-pub-9676260030977388/5413826350"
    #endif
}
