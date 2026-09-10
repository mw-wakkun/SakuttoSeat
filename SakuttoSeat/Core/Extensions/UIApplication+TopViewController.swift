//
//  UIApplication+TopViewController.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（共通拡張の切り出し）
//  もとは RewardedAdManager.swift に同居していた横断的なヘルパー。
//

import UIKit

extension UIApplication {
    /// 最前面に表示されている ViewController を安全に取得するヘルパー
    ///
    /// UIKit のモーダル提示（シェアシート・リワード広告など）に必要となるため、
    /// Phase 4 以降は Router 層からのみ参照する想定。
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
