//
//  AnchoredAdaptiveBannerSize.h
//  SakuttoSeat
//
//  GMA 13 は Swift の currentOrientationAnchoredAdaptiveBanner を deprecated にした。
//  large は高すぎるため旧サイズ（50〜90pt）を ObjC 側で呼ぶ。
//

#import <CoreGraphics/CoreGraphics.h>
#import <GoogleMobileAds/GADAdSize.h>

GADAdSize SakuttoSeatAnchoredAdaptiveBannerAdSize(CGFloat width);
