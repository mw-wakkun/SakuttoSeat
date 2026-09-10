//
//  FeatureUnlockGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//

import Foundation

nonisolated protocol FeatureUnlockGateway: AnyObject {
    var isSessionUnlocked: Bool { get }
    func grantSessionUnlock()
}
