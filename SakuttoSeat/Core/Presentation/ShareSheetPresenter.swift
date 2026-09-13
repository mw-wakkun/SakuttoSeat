//
//  ShareSheetPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（UIActivityViewController の唯一の窓口）
//

import UIKit

@MainActor
enum ShareSheetPresenter {
    /// 最前面 VC へ即座にシェアシートを提示する。提示できなければ false（cleanup はしない）。
    @discardableResult
    static func present(items: [Any], cleanup: (() -> Void)? = nil) -> Bool {
        guard let topViewController = UIApplication.shared.topViewController,
              !topViewController.isBeingDismissed,
              !topViewController.isBeingPresented,
              topViewController.presentedViewController == nil else {
            return false
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let cleanup {
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                cleanup()
            }
        }

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = topViewController.view
            popoverController.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        topViewController.present(activityVC, animated: true, completion: nil)
        return true
    }

    /// シート閉じ終わりなど、提示可能な状態になるまで待ってからシェアする。
    /// 待てなかった／キャンセルされたときは提示せず false。
    @discardableResult
    static func presentWhenReady(items: [Any], cleanup: (() -> Void)? = nil) async -> Bool {
        guard await waitUntilPresentable() else { return false }
        return present(items: items, cleanup: cleanup)
    }

    /// ルート上に presented VC が無い／遷移中でない状態をポーリングで待つ。
    /// 提示できる状態になったら true。タイムアウトやキャンセルは false。
    @discardableResult
    static func waitUntilPresentable(timeoutNanoseconds: UInt64 = 2_000_000_000) async -> Bool {
        let started = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
            if Task.isCancelled { return false }
            if isRootPresentable() {
                return true
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                return false
            }
        }
        return isRootPresentable()
    }

    private static func isRootPresentable() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            // シーンなし（ユニットテスト）＝待つ対象がない
            return true
        }
        guard let window = scene.windows.first(where: \.isKeyWindow),
              let root = window.rootViewController else {
            return false
        }

        // ルート／別シートが残っている間は提示しない
        if root.presentedViewController != nil {
            return false
        }

        if let top = UIApplication.shared.topViewController,
           top.isBeingDismissed || top.isBeingPresented {
            return false
        }

        return true
    }
}
