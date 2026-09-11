//
//  AnchoredAdaptiveBannerSize.m
//  SakuttoSeat
//

#import "AnchoredAdaptiveBannerSize.h"

GADAdSize SakuttoSeatAnchoredAdaptiveBannerAdSize(CGFloat width) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width);
#pragma clang diagnostic pop
}
