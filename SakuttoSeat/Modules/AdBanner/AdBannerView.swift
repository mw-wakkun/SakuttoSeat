//
//  AdBannerView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/16.
//

import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        
        // 環境に応じてIDを自動切り替え
        #if DEBUG
        // デバッグ時は、Google公式テストIDを使用
        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        banner.adUnitID = "ca-app-pub-4933931445771146/1029143922"
        #endif
        
        // 広告を表示するViewControllerを設定
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
        }
        
        // 広告の読み込み要求を実行
        banner.load(Request())
        
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // 更新時の処理は不要です
    }
}
