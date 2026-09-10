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
    private var onRewardEarned: (() -> Void)?
    private var hasEarnedReward = false
    
    var adUnitID: String {
        // 環境に応じてIDを自動切り替え
        #if DEBUG
        // デバッグ時はリワード広告用の Google 公式テストIDを使用
        return "ca-app-pub-3940256099942544/5224354917"
        #else
        // AdMob管理画面で発行した本番用の広告ユニットID
        return "ca-app-pub-9676260030977388/5413826350"
        #endif
    }
    
    private override init() {
        super.init()
        loadAd()
    }
    
    func loadAd() {
        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
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
    }
    
    func showAd(onRewardEarned: @escaping () -> Void) {
        // 最前面の ViewController から提示する
        guard let rewardedAd = rewardedAd,
              let topViewController = UIApplication.shared.topViewController else {
            print("広告が準備できていないか、画面が見つかりません")
            loadAd()
            return
        }
        
        hasEarnedReward = false
        self.onRewardEarned = onRewardEarned
        
        // 報酬付与は広告クローズ後に実行し、シェアシート等の後続UIと衝突しないようにする
        rewardedAd.present(from: topViewController) { [weak self] in
            Task { @MainActor [weak self] in
                self?.hasEarnedReward = true
            }
        }
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let handler = hasEarnedReward ? onRewardEarned : nil
        hasEarnedReward = false
        onRewardEarned = nil
        loadAd()
        handler?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("広告表示エラー: \(error.localizedDescription)")
        hasEarnedReward = false
        onRewardEarned = nil
        loadAd()
    }
}
