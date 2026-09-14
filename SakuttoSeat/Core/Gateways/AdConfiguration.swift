//
//  AdConfiguration.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 1（バナー / リワードのユニット ID を 1 箇所に集約）
//

import Foundation
import StoreKit

/// 広告ユニット ID。DEBUG と TestFlight は Google 公式サンプル、App Store 本番だけ本番 ID。
///
/// TestFlight も Release ビルドだが、`AppTransaction.environment` が sandbox なのでサンプル ID になる。
/// 端末ハッシュ（`testDeviceIdentifiers`）には依存しない。
///
/// `nonisolated`: バナー Representable / Gateway 実装の両方から読むため。
nonisolated enum AdConfiguration {
    static let googleSampleBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let googleSampleRewardedUnitID = "ca-app-pub-3940256099942544/5224354917"
    static let productionBannerUnitID = "ca-app-pub-9676260030977388/3254679876"
    static let productionRewardedUnitID = "ca-app-pub-9676260030977388/5413826350"

    static func resolvedBannerUnitID() async -> String {
        await resolvedUsesTestAdUnits() ? googleSampleBannerUnitID : productionBannerUnitID
    }

    static func resolvedRewardedUnitID() async -> String {
        await resolvedUsesTestAdUnits() ? googleSampleRewardedUnitID : productionRewardedUnitID
    }

    /// DEBUG、TestFlight、判定不能はテスト広告。App Store の production だけ false。
    static func resolvedUsesTestAdUnits() async -> Bool {
        #if DEBUG
        selectsTestAdUnits(isDebugBuild: true, distribution: .appStoreProduction)
        #else
        selectsTestAdUnits(isDebugBuild: false, distribution: await currentDistribution())
        #endif
    }

    /// 起動時に environment を先読みする。広告 load 側でも待つので、呼ばれなくても安全。
    static func prepare() async {
        _ = await resolvedUsesTestAdUnits()
    }

    /// App Store 本番以外はテスト広告にする。判定不能なら本番広告を出さない。
    static func selectsTestAdUnits(isDebugBuild: Bool, distribution: AdsDistribution) -> Bool {
        if isDebugBuild {
            return true
        }
        return distribution != .appStoreProduction
    }

    static func distribution(from environment: AppStore.Environment?) -> AdsDistribution {
        environment == .production ? .appStoreProduction : .testFlightOrUnknown
    }

    /// StoreKit の environment。production 以外（TestFlight / Xcode / 不明）はテスト広告。
    enum AdsDistribution: Equatable {
        case appStoreProduction
        case testFlightOrUnknown
    }

    #if !DEBUG
    private static let environmentTask = Task<AppStore.Environment?, Never> {
        do {
            switch try await AppTransaction.shared {
            case .verified(let transaction), .unverified(let transaction, _):
                return transaction.environment
            }
        } catch {
            return nil
        }
    }

    private static func currentDistribution() async -> AdsDistribution {
        distribution(from: await environmentTask.value)
    }
    #endif
}
