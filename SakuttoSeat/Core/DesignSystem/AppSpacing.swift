//
//  AppSpacing.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 6（ボトム余白・バナーサイズ・CTA 寸法）
//

import CoreGraphics

enum AppSpacing {
    /// エントリ画面の左右余白（入力・CTA）
    static let screenHorizontal: CGFloat = 24
    /// ボトムクロム（CTA + バナー）の上余白
    static let bottomChromeTop: CGFloat = 12
    /// CTA 同士の間隔
    static let ctaStackSpacing: CGFloat = 12
    /// プライマリ / セカンダリ CTA の高さ
    static let ctaButtonHeight: CGFloat = 56
    static let ctaCornerRadius: CGFloat = 15
    static let ctaShadowRadius: CGFloat = 8
    static let ctaShadowY: CGFloat = 4
    /// バナー上下のパディング。`AdBannerContainer` が内部で使う（呼び出し側では付けない）
    static let bannerVerticalPadding: CGFloat = 4
    /// 幅未確定時のバナー高さの初期値（実サイズはアダプティブ）
    static let bannerFallbackHeight: CGFloat = 50
    /// 空状態アイコンと文言の間隔
    static let emptyStateSpacing: CGFloat = 20
}
