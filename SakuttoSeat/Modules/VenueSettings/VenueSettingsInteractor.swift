//
//  VenueSettingsInteractor.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5
//  もとは SettingsSheetView.applySelection() が抱えていた列数の課金ルール。
//

import Foundation

nonisolated final class VenueSettingsInteractor: VenueSettingsInteractorProtocol {
    let selectableRange: ClosedRange<Int> = 1...FeatureLimit.maxColumnCount

    /// Protocol existential は保持しない（deinit の malloc abort 回避）
    private let featureUnlock: FeatureUnlockState
    private(set) var selectedColumnCount: Int

    init(currentColumnCount: Int, featureUnlock: FeatureUnlockState) {
        self.featureUnlock = featureUnlock
        self.selectedColumnCount = min(max(currentColumnCount, 1), FeatureLimit.maxColumnCount)
    }

    var isSessionUnlocked: Bool {
        featureUnlock.isSessionUnlocked
    }

    @discardableResult
    func select(_ columnCount: Int) -> Int {
        selectedColumnCount = min(max(columnCount, selectableRange.lowerBound), selectableRange.upperBound)
        return selectedColumnCount
    }

    /// 会場拡張の要否。無料列以内、またはセッション解放済みなら広告不要。
    func applyRequirement() -> UnlockRequirement {
        if selectedColumnCount <= FeatureLimit.freeColumnCount {
            return .none
        }
        return featureUnlock.isSessionUnlocked ? .none : .rewardedAd
    }

    func grantSessionUnlock() {
        featureUnlock.grantSessionUnlock()
    }
}
