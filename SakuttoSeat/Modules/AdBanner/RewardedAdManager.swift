//
//  RewardedAdManager.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/17.
//


import Foundation
import Combine
import GoogleMobileAds
import UIKit

final class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()
    
    private var rewardedAd: RewardedAd?
    @Published var isAdReady: Bool = false
    
    var adUnitID: String {
        // 環境に応じてIDを自動切り替え
        #if DEBUG
        // テスト用広告ユニットID
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        // AdMob管理画面で発行した本番用の広告ユニットID
        return "ca-app-pub-9676260030977388/3254679876"
        #endif
    }
    
    private override init() {
        super.init()
        loadAd()
    }
    
    func loadAd() {
        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                print("リワード広告読み込み失敗: \(error.localizedDescription)")
                self.isAdReady = false
                return
            }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.isAdReady = true
            print("リワード広告の準備が完了しました")
        }
    }
    
    func showAd(onRewardEarned: @escaping () -> Void) {
        // ★ 最前面の ViewController から表示するように変更
        guard let rewardedAd = rewardedAd,
              let topViewController = UIApplication.shared.topViewController else {
            print("広告が準備できていないか、画面が見つかりません")
            loadAd()
            return
        }
        
        rewardedAd.present(from: topViewController) {
            onRewardEarned()
        }
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("広告表示エラー: \(error.localizedDescription)")
        loadAd()
    }
}

extension UIApplication {
    /// 最前面に表示されている ViewController を安全に取得するヘルパー
    var topViewController: UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              var topVC = window.rootViewController else {
            return nil
        }
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
