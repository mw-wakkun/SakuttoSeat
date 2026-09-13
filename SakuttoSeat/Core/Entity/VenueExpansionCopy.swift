//
//  VenueExpansionCopy.swift
//  SakuttoSeat
//
//  v2.1（人数・会場拡張のユーザー向け文言。数字は FeatureLimit から組み立てる）
//

import Foundation

/// 会場拡張（セッション解放）と人数／卓のハード上限コピー。
/// Share / お気に入り4枠目の文言はここへ混ぜない。
enum VenueExpansionCopy {
    static let later = "あとで"
    static let ok = "OK"

    static let attendeeUnlockTitle = "人数を増やせます"
    static let attendeeUnlockPrimary = "動画を見て追加する"

    static var attendeeUnlockMessage: String {
        "無料では\(FeatureLimit.freeAttendeeCount)人までです。動画を1本見ると、今回の席決めでは\(FeatureLimit.maxAttendeeCount)人まで追加できます。"
    }

    static func attendeeOverflowMessage(triedCount: Int, remainingFree: Int, remainingHard: Int) -> String {
        let exceedsHardLimit = triedCount > remainingHard
        if remainingFree > 0 {
            if exceedsHardLimit {
                return "\(triedCount)人のうち、\(remainingFree)人までは無料で追加できます。動画を1本見ると、上限（\(FeatureLimit.maxAttendeeCount)人）まで追加されます。"
            }
            return "\(triedCount)人のうち、\(remainingFree)人までは無料で追加できます。動画を1本見ると、残りもすべて追加されます。"
        }
        if exceedsHardLimit {
            return "無料枠（\(FeatureLimit.freeAttendeeCount)人）を使い切っています。動画を1本見ると、上限（\(FeatureLimit.maxAttendeeCount)人）まで追加できます。"
        }
        return "無料枠（\(FeatureLimit.freeAttendeeCount)人）を使い切っています。動画を1本見ると、追加しようとする全員を登録できます。"
    }

    static let venueUnlockTitle = "会場を広げます"
    static let venueUnlockPrimary = "動画を見て広げる"

    static var venueUnlockMessage: String {
        "\(FeatureLimit.freeColumnCount + 1)列以上の配置や、テーブルを増やすには動画が1本必要です。見終わると、この席決めでは上限まで使えます。"
    }

    static var venueNotice: String {
        "1〜\(FeatureLimit.freeColumnCount)列はすぐ使えます。\(FeatureLimit.freeColumnCount + 1)列以上は動画1本で、この席決めのあいだ人数・テーブルも含めて開きます。"
    }

    static let hardLimitTitle = "これ以上は追加できません"
    static let hardLimitOverflowTitle = "人数の上限です"

    static var attendeeHardLimitMessage: String {
        "一度に扱えるのは\(FeatureLimit.maxAttendeeCount)人までです。人数を減らしてから追加してください。"
    }

    static func attendeeHardLimitOverflowMessage(triedCount: Int, remainingHard: Int) -> String {
        "\(triedCount)人のうち、\(remainingHard)人まで追加できます。上限（\(FeatureLimit.maxAttendeeCount)人）を超える分は追加できません。"
    }

    static var attendeeInputHardLimitPlaceholder: String {
        "上限（\(FeatureLimit.maxAttendeeCount)人）に達しました"
    }

    static var tableHardLimitMessage: String {
        "一度に置けるテーブルは\(FeatureLimit.maxTableCount)までです。テーブルを減らしてから追加してください。"
    }

    static let totalSeatHardLimitMessage =
        "これ以上テーブルを増やすと表示しきれません。テーブルを減らすか、定員を下げてください。"

    static var tableLimitCaption: String {
        "テーブルは\(FeatureLimit.maxTableCount)まで"
    }

    static let seatShortageTitle = "座席数が不足します"
    static let seatShortagePrimary = "適用する"
    static let seatShortageCancel = "キャンセル"

    static var seatShortageMessage: String {
        "テーブル数の上限（\(FeatureLimit.maxTableCount)卓）に達するため、全員を配置できません。残りの参加者は未配置となります。このまま適用しますか？"
    }
}
