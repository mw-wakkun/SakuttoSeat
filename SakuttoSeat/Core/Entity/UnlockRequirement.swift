//
//  UnlockRequirement.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 1（SeatingChartEntity から移設。Share / VenueSettings も使う共通 Entity）
//

import Foundation

/// 列数変更や画像共有などに必要な解放条件
///
/// `nonisolated`: Interactor（nonisolated）の戻り値として使うため。
nonisolated enum UnlockRequirement: Equatable {
    case none
    case rewardedAd
}
