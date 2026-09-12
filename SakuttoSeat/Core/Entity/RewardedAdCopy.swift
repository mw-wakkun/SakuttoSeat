//
//  RewardedAdCopy.swift
//  SakuttoSeat
//
//  refactor_Ad.md Phase 4（Share / VenueSettings の未準備アラート文言を単一化）
//

import Foundation

/// リワード未準備時のユーザー向け文言。Share / VenueSettings / AttendeeList で同じコピーを使う。
enum RewardedAdCopy {
    static let notReadyTitle = "広告の準備ができていません"
    static let notReadyMessage = "広告の準備ができていません。しばらく待ってからもう一度お試しください。"
}
